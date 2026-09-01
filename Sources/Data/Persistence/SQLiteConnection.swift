import Foundation
import SQLite3

/// A single SQLite connection with a small typed surface. **Not thread-safe on
/// its own** — `CatalogDatabase` pins each connection to one serial
/// `DispatchQueue` and never lets it escape, which is what makes the
/// `@unchecked Sendable` here sound.
final class SQLiteConnection: @unchecked Sendable {

    /// How the connection participates in the store's two-connection model.
    enum Role {
        /// The importer's connection: sets WAL + the durability pragmas.
        case writer
        /// A read-only view (`PRAGMA query_only`) that serves queries while the
        /// writer commits. WAL lets it read a consistent snapshot concurrently.
        case reader
    }

    enum SQLiteError: Error, CustomStringConvertible {
        case open(code: Int32, message: String)
        case prepare(sql: String, code: Int32, message: String)
        case step(code: Int32, message: String)
        case bind(index: Int, code: Int32, message: String)

        var description: String {
            switch self {
            case let .open(code, message):
                return "SQLite open failed (\(code)): \(message)"
            case let .prepare(sql, code, message):
                return "SQLite prepare failed (\(code)): \(message)\n  \(sql)"
            case let .step(code, message):
                return "SQLite step failed (\(code)): \(message)"
            case let .bind(index, code, message):
                return "SQLite bind failed at \(index) (\(code)): \(message)"
            }
        }
    }

    private var handle: OpaquePointer?

    /// `sqlite3_open_v2` on the given file path. Creates the file if missing.
    init(path: String, role: Role = .writer) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK, handle != nil else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if handle != nil { sqlite3_close_v2(handle) }
            handle = nil
            throw SQLiteError.open(code: rc, message: message)
        }
        sqlite3_busy_timeout(handle, 5_000)
        switch role {
        case .writer:
            // Durability tuned for a disposable, rebuildable catalog store
            // written in big streaming batches and read in small pages.
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA synchronous = NORMAL")
            try execute("PRAGMA temp_store = MEMORY")
            try execute("PRAGMA foreign_keys = ON")
            try execute("PRAGMA cache_size = -4000")   // ~4 MB page cache
        case .reader:
            // Journal mode + durability come from the file (the writer set them).
            try? execute("PRAGMA query_only = ON")
            try? execute("PRAGMA temp_store = MEMORY")
            try? execute("PRAGMA cache_size = -8000")  // the hot path — 8 MB
        }
    }

    deinit {
        for (_, statement) in statementCache { statement.finalize() }
        statementCache.removeAll()
        if handle != nil { sqlite3_close_v2(handle) }
    }

    var lastErrorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no connection"
    }

    /// Run one or more semicolon-separated statements with no bindings and no
    /// result rows (DDL, PRAGMA, BEGIN/COMMIT).
    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &errorPointer)
        guard rc == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(errorPointer)
            throw SQLiteError.step(code: rc, message: message)
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard rc == SQLITE_OK, let statement else {
            throw SQLiteError.prepare(sql: sql, code: rc, message: lastErrorMessage)
        }
        return SQLiteStatement(handle: statement, connection: self)
    }

    // MARK: - Prepared-statement cache

    /// Compiled statements, keyed by SQL. Re-compiling a statement costs more
    /// than running it for the small, repeated queries the browse screens fire,
    /// so each one is compiled once and then reset+rebound. Bounded so a query
    /// built with an `IN (?,?,…)` list of varying width can't grow it forever.
    private var statementCache: [String: SQLiteStatement] = [:]
    /// SQL currently being stepped — a nested call on the same text must not
    /// reuse (and reset) the statement the outer loop is walking.
    private var checkedOut: Set<String> = []
    private static let statementCacheLimit = 64

    /// Run `body` against a compiled statement for `sql`, reusing a cached one
    /// where possible.
    private func withStatement<T>(_ sql: String, _ body: (SQLiteStatement) throws -> T) throws -> T {
        if let cached = statementCache[sql], !checkedOut.contains(sql) {
            checkedOut.insert(sql)
            defer { checkedOut.remove(sql); sqlite3_reset(cached.handle) }
            return try body(cached)
        }
        // Not cached (or already in use further up the stack) — compile a fresh
        // one. Only the un-nested case is worth keeping.
        let statement = try prepare(sql)
        if !checkedOut.contains(sql), statementCache.count < Self.statementCacheLimit {
            statementCache[sql] = statement
            checkedOut.insert(sql)
            defer { checkedOut.remove(sql); sqlite3_reset(statement.handle) }
            return try body(statement)
        }
        defer { statement.finalize() }
        return try body(statement)
    }

    /// Drop every cached statement. Call before the schema changes underneath
    /// them (migrations) — a compiled statement over a dropped table is invalid.
    func clearStatementCache() {
        for (_, statement) in statementCache { statement.finalize() }
        statementCache.removeAll()
    }

    /// Prepare, bind, and step an INSERT/UPDATE/DELETE to completion.
    /// Returns the number of rows changed.
    @discardableResult
    func run(_ sql: String, _ parameters: [SQLiteValue] = []) throws -> Int {
        try withStatement(sql) { statement in
            try statement.bind(parameters)
            try statement.stepToCompletion()
            return Int(sqlite3_changes(handle))
        }
    }

    /// Prepare one statement and run it once per row of `parameterRows`. Far
    /// cheaper than `run(_:_:)` in a loop — the statement is compiled once.
    /// Wrap the call in `transaction` for a bulk insert.
    func executeMany(_ sql: String, _ parameterRows: [[SQLiteValue]]) throws {
        guard !parameterRows.isEmpty else { return }
        try withStatement(sql) { statement in
            for row in parameterRows {
                try statement.bind(row)
                try statement.stepToCompletion()
            }
        }
    }

    /// Prepare, bind, and collect every result row via `decode`.
    func query<T>(
        _ sql: String,
        _ parameters: [SQLiteValue] = [],
        _ decode: (SQLiteRow) throws -> T
    ) throws -> [T] {
        try withStatement(sql) { statement in
            try statement.bind(parameters)
            var rows: [T] = []
            while try statement.step() {
                rows.append(try decode(SQLiteRow(statement)))
            }
            return rows
        }
    }

    /// The first result row, or `nil` when the query returned nothing.
    func queryOne<T>(
        _ sql: String,
        _ parameters: [SQLiteValue] = [],
        _ decode: (SQLiteRow) throws -> T
    ) throws -> T? {
        try withStatement(sql) { statement in
            try statement.bind(parameters)
            return try statement.step() ? try decode(SQLiteRow(statement)) : nil
        }
    }

    /// A single integer scalar (`SELECT count(*) …`). `0` when there is no row.
    func scalarInt(_ sql: String, _ parameters: [SQLiteValue] = []) throws -> Int {
        try queryOne(sql, parameters) { $0.int(0) } ?? 0
    }

    /// Run `body` inside `BEGIN IMMEDIATE` … `COMMIT`, rolling back on any throw.
    /// Not re-entrant — callers never nest transactions.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }
}

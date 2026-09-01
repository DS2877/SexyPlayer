import Foundation
import SQLite3

/// A single SQLite connection with a small typed surface. **Not thread-safe on
/// its own** — every caller in the app reaches it through `CatalogDatabase`, an
/// `actor`, so access is already serialised. Keeping it a plain `final class`
/// (not `Sendable`) is deliberate: the actor owns it and never hands it out.
final class SQLiteConnection {

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
    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK, handle != nil else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if handle != nil { sqlite3_close_v2(handle) }
            handle = nil
            throw SQLiteError.open(code: rc, message: message)
        }
        sqlite3_busy_timeout(handle, 5_000)
        // Durability tuned for a disposable, rebuildable catalog store that's
        // written in big streaming batches and read in small pages.
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA temp_store = MEMORY")
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA cache_size = -4000")   // ~4 MB page cache, not more
    }

    deinit {
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

    /// Prepare, bind, and step an INSERT/UPDATE/DELETE to completion.
    /// Returns the number of rows changed.
    @discardableResult
    func run(_ sql: String, _ parameters: [SQLiteValue] = []) throws -> Int {
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind(parameters)
        try statement.stepToCompletion()
        return Int(sqlite3_changes(handle))
    }

    /// Prepare one statement and run it once per row of `parameterRows`. Far
    /// cheaper than `run(_:_:)` in a loop — the statement is compiled once.
    /// Wrap the call in `transaction` for a bulk insert.
    func executeMany(_ sql: String, _ parameterRows: [[SQLiteValue]]) throws {
        guard !parameterRows.isEmpty else { return }
        let statement = try prepare(sql)
        defer { statement.finalize() }
        for row in parameterRows {
            try statement.bind(row)
            try statement.stepToCompletion()
        }
    }

    /// Prepare, bind, and collect every result row via `decode`.
    func query<T>(
        _ sql: String,
        _ parameters: [SQLiteValue] = [],
        _ decode: (SQLiteRow) throws -> T
    ) throws -> [T] {
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind(parameters)
        var rows: [T] = []
        while try statement.step() {
            rows.append(try decode(SQLiteRow(statement)))
        }
        return rows
    }

    /// The first result row, or `nil` when the query returned nothing.
    func queryOne<T>(
        _ sql: String,
        _ parameters: [SQLiteValue] = [],
        _ decode: (SQLiteRow) throws -> T
    ) throws -> T? {
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind(parameters)
        return try statement.step() ? try decode(SQLiteRow(statement)) : nil
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

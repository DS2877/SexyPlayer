import Foundation
import SQLite3

/// `SQLITE_TRANSIENT` isn't imported into Swift. This is the standard idiom: it
/// tells SQLite to copy a bound string/blob immediately rather than keep the
/// pointer, so bridged Swift buffers that die after the call are safe.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Bindable value

/// A value that can be bound to a `?` placeholder. `nil`-carrying initialisers
/// map an absent optional to `NULL`.
enum SQLiteValue {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    init(_ value: Int) { self = .integer(Int64(value)) }
    init(_ value: Int?) { self = value.map { .integer(Int64($0)) } ?? .null }
    init(_ value: Int64) { self = .integer(value) }
    init(_ value: Bool) { self = .integer(value ? 1 : 0) }
    init(_ value: Double) { self = .real(value) }
    init(_ value: Double?) { self = value.map { .real($0) } ?? .null }
    init(_ value: String) { self = .text(value) }
    init(_ value: String?) { self = value.map { .text($0) } ?? .null }
    init(_ value: URL?) { self = value.map { .text($0.absoluteString) } ?? .null }
    init(date value: Date?) { self = value.map { .real($0.timeIntervalSince1970) } ?? .null }
}

// MARK: - Prepared statement

/// One prepared statement. Reused across `bind` calls; the owner must call
/// `finalize()` (via `defer`) exactly once.
final class SQLiteStatement {
    let handle: OpaquePointer
    private unowned let connection: SQLiteConnection

    init(handle: OpaquePointer, connection: SQLiteConnection) {
        self.handle = handle
        self.connection = connection
    }

    func finalize() {
        sqlite3_finalize(handle)
    }

    /// Reset any prior execution, then bind `values` to `?1…?n` in order.
    func bind(_ values: [SQLiteValue]) throws {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let rc: Int32
            switch value {
            case .null:
                rc = sqlite3_bind_null(handle, index)
            case .integer(let number):
                rc = sqlite3_bind_int64(handle, index, number)
            case .real(let number):
                rc = sqlite3_bind_double(handle, index, number)
            case .text(let string):
                rc = sqlite3_bind_text(handle, index, string, -1, SQLITE_TRANSIENT)
            case .blob(let data):
                rc = data.withUnsafeBytes { raw in
                    sqlite3_bind_blob(handle, index, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
                }
            }
            guard rc == SQLITE_OK else {
                throw SQLiteConnection.SQLiteError.bind(
                    index: offset + 1, code: rc, message: connection.lastErrorMessage
                )
            }
        }
    }

    /// Advance one row. `true` = a row is available, `false` = statement done.
    func step() throws -> Bool {
        switch sqlite3_step(handle) {
        case SQLITE_ROW:  return true
        case SQLITE_DONE: return false
        case let rc:
            throw SQLiteConnection.SQLiteError.step(code: rc, message: connection.lastErrorMessage)
        }
    }

    /// Step a non-SELECT statement to `SQLITE_DONE`.
    func stepToCompletion() throws {
        while try step() {}
    }
}

// MARK: - Result row

/// Column accessors for the current row of a stepped statement. Indices are
/// 0-based and match the `SELECT` column order.
struct SQLiteRow {
    private let handle: OpaquePointer

    init(_ statement: SQLiteStatement) {
        self.handle = statement.handle
    }

    func isNull(_ index: Int) -> Bool {
        sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL
    }

    func int(_ index: Int) -> Int {
        Int(sqlite3_column_int64(handle, Int32(index)))
    }

    func intOrNil(_ index: Int) -> Int? {
        isNull(index) ? nil : int(index)
    }

    func bool(_ index: Int) -> Bool {
        sqlite3_column_int64(handle, Int32(index)) != 0
    }

    func double(_ index: Int) -> Double {
        sqlite3_column_double(handle, Int32(index))
    }

    func doubleOrNil(_ index: Int) -> Double? {
        isNull(index) ? nil : double(index)
    }

    func date(_ index: Int) -> Date? {
        isNull(index) ? nil : Date(timeIntervalSince1970: double(index))
    }

    func string(_ index: Int) -> String {
        guard let cString = sqlite3_column_text(handle, Int32(index)) else { return "" }
        return String(cString: cString)
    }

    func stringOrNil(_ index: Int) -> String? {
        guard !isNull(index), let cString = sqlite3_column_text(handle, Int32(index)) else { return nil }
        return String(cString: cString)
    }

    func url(_ index: Int) -> URL? {
        stringOrNil(index).flatMap(URL.init(string:))
    }
}

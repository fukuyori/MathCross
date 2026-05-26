import Foundation
import SQLite3

struct PreparedPuzzleCatalog {
    static let shared = PreparedPuzzleCatalog()

    private let databaseURL: URL?

    init(bundle: Bundle = .main) {
        databaseURL = bundle.url(forResource: "PreparedPuzzles", withExtension: "sqlite")
    }

    func puzzle(for key: PuzzleCacheKey, excluding usedIDs: Set<Int>) -> (id: Int, puzzle: PlayablePuzzle)? {
        guard let databaseURL else {
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return nil
        }

        defer {
            sqlite3_close(database)
        }

        if let unusedPuzzle = fetchPuzzle(
            from: database,
            key: key,
            excluding: usedIDs,
            allowUsed: false
        ) {
            return unusedPuzzle
        }

        return fetchPuzzle(
            from: database,
            key: key,
            excluding: usedIDs,
            allowUsed: true
        )
    }

    func count(for key: PuzzleCacheKey) -> Int {
        guard let databaseURL else {
            return 0
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return 0
        }

        defer {
            sqlite3_close(database)
        }

        let sql = "SELECT COUNT(*) FROM puzzles WHERE block_count = ? AND difficulty = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return 0
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int(statement, 1, Int32(key.blockCount))
        sqlite3_bind_text(statement, 2, key.difficulty.rawValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func fetchPuzzle(
        from database: OpaquePointer?,
        key: PuzzleCacheKey,
        excluding usedIDs: Set<Int>,
        allowUsed: Bool
    ) -> (id: Int, puzzle: PlayablePuzzle)? {
        var sql = """
            SELECT id, puzzle_data
            FROM puzzles
            WHERE block_count = ? AND difficulty = ?
            """

        let filteredIDs = allowUsed ? [] : usedIDs.sorted()
        if !filteredIDs.isEmpty {
            let placeholders = Array(repeating: "?", count: filteredIDs.count).joined(separator: ",")
            sql += " AND id NOT IN (\(placeholders))"
        }

        sql += " ORDER BY RANDOM() LIMIT 1"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int(statement, 1, Int32(key.blockCount))
        sqlite3_bind_text(statement, 2, key.difficulty.rawValue, -1, SQLITE_TRANSIENT)

        for (offset, id) in filteredIDs.enumerated() {
            sqlite3_bind_int(statement, Int32(offset + 3), Int32(id))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        let id = Int(sqlite3_column_int(statement, 0))
        guard
            let bytes = sqlite3_column_blob(statement, 1),
            sqlite3_column_bytes(statement, 1) > 0
        else {
            return nil
        }

        let byteCount = Int(sqlite3_column_bytes(statement, 1))
        let data = Data(bytes: bytes, count: byteCount)

        guard let puzzle = try? JSONDecoder().decode(PlayablePuzzle.self, from: data) else {
            return nil
        }

        return (id, puzzle)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

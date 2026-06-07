import Foundation
import SQLite3

struct PreparedPuzzleCatalog {
    static let shared = PreparedPuzzleCatalog()

    private let databaseURL: URL?

    init(bundle: Bundle = .main) {
        databaseURL = bundle.url(forResource: "PreparedPuzzles", withExtension: "sqlite")
    }

    func levelKeys() -> [PuzzleCacheKey] {
        guard let databaseURL else {
            return []
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return []
        }

        defer {
            sqlite3_close(database)
        }

        let sql = """
            SELECT level, MIN(block_count), difficulty
            FROM puzzles
            GROUP BY level
            ORDER BY level
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }

        defer {
            sqlite3_finalize(statement)
        }

        var keys: [PuzzleCacheKey] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let level = Int(sqlite3_column_int(statement, 0))
            let blockCount = Int(sqlite3_column_int(statement, 1))
            let difficultyText = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
            let difficulty = PuzzleDifficulty(rawValue: difficultyText) ?? .advanced
            keys.append(PuzzleCacheKey(level: level, blockCount: blockCount, difficulty: difficulty))
        }

        return keys
    }

    func puzzle(for key: PuzzleCacheKey, excluding completedIDs: Set<Int>) -> (id: Int, puzzle: PlayablePuzzle)? {
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
            excluding: completedIDs
        ) {
            return unusedPuzzle
        }

        return nil
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

        let sql = "SELECT COUNT(*) FROM puzzles WHERE level = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return 0
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int(statement, 1, Int32(key.sourceLevel))

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func fetchPuzzle(
        from database: OpaquePointer?,
        key: PuzzleCacheKey,
        excluding completedIDs: Set<Int>
    ) -> (id: Int, puzzle: PlayablePuzzle)? {
        var sql = """
            SELECT id, puzzle_data
            FROM puzzles
            WHERE level = ?
            """

        let filteredIDs = completedIDs.sorted()
        if !filteredIDs.isEmpty {
            let placeholders = Array(repeating: "?", count: filteredIDs.count).joined(separator: ",")
            sql += " AND id NOT IN (\(placeholders))"
        }

        sql += " ORDER BY RANDOM()"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int(statement, 1, Int32(key.sourceLevel))

        for (offset, id) in filteredIDs.enumerated() {
            sqlite3_bind_int(statement, Int32(offset + 2), Int32(id))
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard
                let bytes = sqlite3_column_blob(statement, 1),
                sqlite3_column_bytes(statement, 1) > 0
            else {
                continue
            }

            let byteCount = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: bytes, count: byteCount)

            guard
                let puzzle = try? JSONDecoder().decode(PlayablePuzzle.self, from: data),
                puzzle.isPlayablePattern
            else {
                continue
            }

            return (id, puzzle)
        }

        return nil
    }
}

private extension PlayablePuzzle {
    var isPlayablePattern: Bool {
        !visibleContents.isEmpty &&
            (!hiddenNumberPoints.isEmpty || !hiddenOperatorPoints.isEmpty) &&
            (!answerCards.isEmpty || !operatorCards.isEmpty)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

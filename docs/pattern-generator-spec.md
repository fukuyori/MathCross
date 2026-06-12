# はめこみクロスマス Pattern Generator Spec

## Purpose

はめこみクロスマス runtime should not depend on expensive puzzle generation for normal play. A separate pattern generator creates validated puzzle patterns ahead of time and stores them in SQLite. The iOS app reads prepared patterns as a player and does not generate puzzles during normal play.

## Level Model

Levels are derived from block count and difficulty.

- Minimum block count: `3`
- Maximum block count: `18`
- Difficulties in order: `beginner`, `intermediate`, `advanced`, `expert`
- Level formula:

```text
level = (blockCount - 3) * 4 + difficultyIndex + 1
```

Examples:

- Level 1: 3 blocks, beginner
- Level 2: 3 blocks, intermediate
- Level 3: 3 blocks, advanced
- Level 4: 3 blocks, expert
- Level 19: 7 blocks, advanced

## Pattern Text File

The pattern generator first writes a text file:

```text
PreparedPuzzles.jsonl
```

The format is JSON Lines. Each line is one puzzle record, so generation can be resumed or appended without rewriting the whole file.

```json
{"schemaVersion":1,"generatorVersion":"0.1.0-rust","createdAt":1779704282.699302,"level":1,"blockCount":3,"difficulty":"beginner","puzzle":{}}
```

The `puzzle` object must be compatible with Swift `JSONDecoder().decode(PlayablePuzzle.self, from:)`.
Point-keyed dictionaries use Swift `JSONEncoder`'s alternating array representation:

```json
[{"row":5,"column":4},"19",{"row":5,"column":5},"−"]
```

## SQLite File

The runtime bundle file is:

```text
PreparedPuzzles.sqlite
```

The app treats this file as read-only bundled data. It can be produced from `PreparedPuzzles.jsonl` by an importer.

## Schema

```sql
CREATE TABLE IF NOT EXISTS metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS puzzles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level INTEGER NOT NULL,
  block_count INTEGER NOT NULL,
  difficulty TEXT NOT NULL,
  puzzle_data BLOB NOT NULL,
  created_at REAL NOT NULL,
  generator_version TEXT NOT NULL,
  checksum TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puzzles_checksum
ON puzzles(checksum);

CREATE INDEX IF NOT EXISTS idx_puzzles_level
ON puzzles(level);

CREATE INDEX IF NOT EXISTS idx_puzzles_key
ON puzzles(block_count, difficulty);
```

`puzzle_data` is UTF-8 JSON encoded from `PlayablePuzzle` using `JSONEncoder`.

## Validation

Every stored puzzle must pass the same runtime rules as generated puzzles.

- The solution count is exactly one.
- Number cards and operator cards match the puzzle difficulty.
- Expert puzzles include the required operator cards.
- If expert has exactly two hidden operators, the two operators are different.
- At least one number is visible on the board.
- The board size matches block count rules.

Invalid puzzles must not be inserted.

## Rust Generator CLI

The Rust generator writes JSONL text patterns.

```bash
cd tools/pattern_generator_rust
cargo run --release -- --level 19 --count 100 --output ../../PreparedPuzzles.jsonl
cargo run --release -- --all --count-per-level 20 --output ../../PreparedPuzzles.jsonl
```

Recommended targets:

- Current production minimum: 20 patterns per level
- Heavy levels: 50 patterns per level
- Upper bound per level: 100 patterns unless file size becomes a problem

## Runtime Rules

When the app needs a puzzle:

1. Look up bundled SQLite patterns for the requested level.
2. Use a pattern that has not been used in the current app session.
3. If all bundled patterns for the level have been used, allow reuse.
4. If no bundled pattern exists, show the unavailable state instead of generating a puzzle at runtime.

The app is intended to behave as a prepared-puzzle player. Pattern generation is handled outside the app and imported into SQLite before bundling.

## Versioning

Store these metadata keys:

```text
schema_version = 1
generator_version = 0.1.0
app_min_version = 0.2.0
```

If schema changes, bump `schema_version` and update the app reader.

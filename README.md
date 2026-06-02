# MathCross

MathCross is an iPad puzzle game built with SwiftUI. Players fill number and operator cards into crossing five-cell equations, with levels unlocked through clear counts.

![MathCross screenshot](images/screenshot.png)

## Features

- 5-cell math blocks in horizontal and vertical layouts
- Level progression from beginner through expert-style difficulty
- Prepared puzzle catalog loaded from SQLite
- Unique-solution puzzle data support
- Clear counts and level unlock achievements
- Confetti and sound feedback on completion

## Requirements

- macOS with Xcode 26.5 or later
- iOS / iPadOS simulator or device
- Swift 5 project settings

## Build

Open `MathCross.xcodeproj` in Xcode and run the `MathCross` scheme.

Command-line build:

```sh
xcodebuild -project MathCross.xcodeproj -scheme MathCross -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## Puzzle Data

The app reads bundled puzzle patterns from:

```text
MathCross/PreparedPuzzles.sqlite
```

Text puzzle data can be imported from JSONL with the tools under `tools/`. Large generated JSONL files are treated as local intermediates and are ignored by Git.

## Repository

```text
https://github.com/fukuyori/MathCross.git
```

## Version

Current app version: `0.5.0`

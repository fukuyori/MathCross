import Foundation

struct GridPoint: Hashable, Codable {
    let row: Int
    let column: Int

    func moved(_ direction: Direction) -> GridPoint {
        GridPoint(row: row + direction.delta.row, column: column + direction.delta.column)
    }
}

enum Direction: CaseIterable {
    case up
    case down
    case left
    case right

    var delta: (row: Int, column: Int) {
        switch self {
        case .up:
            return (-1, 0)
        case .down:
            return (1, 0)
        case .left:
            return (0, -1)
        case .right:
            return (0, 1)
        }
    }
}

enum BlockOrientation: String, CaseIterable, Codable {
    case horizontal = "横"
    case vertical = "縦"
}

enum ArithmeticOperator: String, CaseIterable, Codable {
    case add = "＋"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"

    func apply(_ lhs: Int, _ rhs: Int) -> Int? {
        switch self {
        case .add:
            return lhs + rhs
        case .subtract:
            let result = lhs - rhs
            return result > 0 ? result : nil
        case .multiply:
            return lhs * rhs
        case .divide:
            guard rhs != 0, lhs % rhs == 0 else { return nil }
            return lhs / rhs
        }
    }

    var sortOrder: Int {
        switch self {
        case .add:
            return 0
        case .subtract:
            return 1
        case .multiply:
            return 2
        case .divide:
            return 3
        }
    }
}

enum PuzzleDifficulty: String, CaseIterable, Identifiable, Codable {
    case beginner
    case intermediate
    case advanced
    case expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner:
            return "初級"
        case .intermediate:
            return "中級"
        case .advanced:
            return "上級"
        case .expert:
            return "狂級"
        }
    }

    var sortOrder: Int {
        switch self {
        case .beginner:
            return 0
        case .intermediate:
            return 1
        case .advanced:
            return 2
        case .expert:
            return 3
        }
    }
}

struct BlockEquation: Codable {
    let lhs: Int
    let operation: ArithmeticOperator
    let rhs: Int
    let result: Int
}

struct BoardBlock: Identifiable, Codable {
    let id: Int
    let orientation: BlockOrientation
    let origin: GridPoint
    let connectorSlots: Set<Int>

    static let length = 5
    static let connectableSlots: Set<Int> = [0, 2, 4]

    var cells: [GridPoint] {
        (0..<Self.length).map { offset in
            switch orientation {
            case .horizontal:
                return GridPoint(row: origin.row, column: origin.column + offset)
            case .vertical:
                return GridPoint(row: origin.row + offset, column: origin.column)
            }
        }
    }

    var connectorCells: [GridPoint] {
        cells.enumerated().compactMap { index, point in
            connectorSlots.contains(index) ? point : nil
        }
    }

    func contains(_ point: GridPoint) -> Bool {
        cells.contains(point)
    }

    func hasConnector(at point: GridPoint) -> Bool {
        connectorCells.contains(point)
    }
}

struct BlockConnection: Identifiable, Codable {
    let id: UUID
    let firstBlockID: Int
    let firstPoint: GridPoint
    let secondBlockID: Int
    let secondPoint: GridPoint

    init(
        id: UUID = UUID(),
        firstBlockID: Int,
        firstPoint: GridPoint,
        secondBlockID: Int,
        secondPoint: GridPoint
    ) {
        self.id = id
        self.firstBlockID = firstBlockID
        self.firstPoint = firstPoint
        self.secondBlockID = secondBlockID
        self.secondPoint = secondPoint
    }
}

struct PlayablePuzzle: Codable {
    let solution: BoardPuzzle
    let visibleContents: [GridPoint: String]
    let answerCards: [Int]
    let operatorCards: [ArithmeticOperator]
    let hiddenNumberPoints: [GridPoint]
    let hiddenOperatorPoints: [GridPoint]
    let givenNumberValues: [GridPoint: Int]
    let givenOperatorValues: [GridPoint: ArithmeticOperator]
}

struct BoardPuzzle: Codable {
    static let defaultSize = 11
    static let expandedSize = 14
    static let largeSize = 16
    static let defaultBlockCount = 3
    static let blockCountRange = 3...18

    let size: Int
    let blocks: [BoardBlock]
    let connections: [BlockConnection]
    let cellContents: [GridPoint: String]
    let equations: [Int: BlockEquation]

    var occupiedCells: Set<GridPoint> {
        Set(blocks.flatMap(\.cells))
    }

    var connectionCounts: [Int: Int] {
        var counts = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, 0) })
        for connection in connections {
            counts[connection.firstBlockID, default: 0] += 1
            counts[connection.secondBlockID, default: 0] += 1
        }
        return counts
    }

    func block(at point: GridPoint) -> BoardBlock? {
        blocks.first { $0.contains(point) }
    }

    func blocks(at point: GridPoint) -> [BoardBlock] {
        blocks.filter { $0.contains(point) }
    }

    func isConnector(at point: GridPoint) -> Bool {
        blocks.contains { $0.hasConnector(at: point) }
    }

    func isSharedConnector(at point: GridPoint) -> Bool {
        blocks(at: point).count > 1
    }

    static func size(for blockCount: Int) -> Int {
        if blockCount >= 20 {
            return largeSize
        }

        return blockCount >= 11 ? expandedSize : defaultSize
    }
}

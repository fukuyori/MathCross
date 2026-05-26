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

    var hiddenCardRatioPercent: Int {
        switch self {
        case .beginner:
            return 45
        case .intermediate:
            return 60
        case .advanced:
            return 62
        case .expert:
            return 66
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

    var hiddenTargetOffset: Int {
        switch self {
        case .beginner:
            return -4
        case .intermediate:
            return 2
        case .advanced:
            return 3
        case .expert:
            return 4
        }
    }

    var maximumNumberOffset: Int {
        switch self {
        case .beginner:
            return 0
        case .intermediate:
            return 5
        case .advanced:
            return 10
        case .expert:
            return 15
        }
    }

    var minimumNumberValue: Int {
        switch self {
        case .beginner:
            return 1
        case .intermediate, .advanced, .expert:
            return 2
        }
    }

    var hidesOperators: Bool {
        self == .expert
    }

    func minimumHiddenOperatorCount(blockCount: Int) -> Int {
        hidesOperators ? min(max(blockCount, 0), 2) : 0
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
    static let defaultBlockCount = 3
    static let blockCountRange = 3...18

    let size: Int
    let blocks: [BoardBlock]
    let connections: [BlockConnection]
    let cellContents: [GridPoint: String]
    let equations: [Int: BlockEquation]

    private static let maximumCandidateValue = 70
    private static let cachedEquationCandidates = makeEquationCandidates(maxValue: maximumCandidateValue)
    private static let cachedCandidatesByOperator = Dictionary(
        grouping: cachedEquationCandidates,
        by: \.operation
    )

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

    static func generatePlayable(
        blockCount requestedBlockCount: Int = defaultBlockCount,
        difficulty: PuzzleDifficulty = .intermediate
    ) -> PlayablePuzzle {
        let blockCount = min(max(requestedBlockCount, blockCountRange.lowerBound), blockCountRange.upperBound)
        let requiredOperatorCards = difficulty.minimumHiddenOperatorCount(blockCount: blockCount)
        var bestPuzzle: PlayablePuzzle?

        for _ in 0..<200 {
            let solution = generate(blockCount: blockCount, difficulty: difficulty)
            let playablePuzzle = solution.asPlayablePuzzle(difficulty: difficulty)

            guard playablePuzzle.operatorCards.count < requiredOperatorCards else {
                return playablePuzzle
            }

            if bestPuzzle == nil || playablePuzzle.operatorCards.count > bestPuzzle!.operatorCards.count {
                bestPuzzle = playablePuzzle
            }
        }

        if requiredOperatorCards > 0 {
            while true {
                let playablePuzzle = generate(blockCount: blockCount, difficulty: difficulty)
                    .asPlayablePuzzle(difficulty: difficulty)

                if playablePuzzle.operatorCards.count >= requiredOperatorCards {
                    return playablePuzzle
                }
            }
        }

        return bestPuzzle ?? generate(blockCount: blockCount, difficulty: difficulty).asPlayablePuzzle(difficulty: difficulty)
    }

    static func generate(
        blockCount requestedBlockCount: Int = defaultBlockCount,
        difficulty: PuzzleDifficulty = .intermediate
    ) -> BoardPuzzle {
        let blockCount = min(max(requestedBlockCount, blockCountRange.lowerBound), blockCountRange.upperBound)
        let boardSize = size(for: blockCount)
        let maximumNumberValue = maximumNumberValue(for: blockCount, difficulty: difficulty)
        let minimumNumberValue = difficulty.minimumNumberValue

        for _ in 0..<50_000 {
            if
                let layout = buildCandidate(blockCount: blockCount, size: boardSize),
                layout.isValid(expectedBlockCount: blockCount),
                let puzzle = layout.withAssignedEquations(
                    minimumNumberValue: minimumNumberValue,
                    maximumNumberValue: maximumNumberValue,
                    difficulty: difficulty
                )
            {
                return puzzle
            }
        }

        let fallbackPuzzle = fallback(blockCount: blockCount, size: boardSize)
        return fallbackPuzzle.withAssignedEquations(
            minimumNumberValue: minimumNumberValue,
            maximumNumberValue: maximumNumberValue,
            difficulty: difficulty
        ) ?? fallbackPuzzle
    }

    static func size(for blockCount: Int) -> Int {
        blockCount >= 11 ? expandedSize : defaultSize
    }

    private static func maximumNumberValue(
        for blockCount: Int,
        difficulty: PuzzleDifficulty
    ) -> Int {
        let baseValue: Int

        switch blockCount {
        case 15...:
            baseValue = 60
        case 11...:
            baseValue = 50
        case 7...:
            baseValue = 40
        default:
            baseValue = 30
        }

        return min(baseValue + difficulty.maximumNumberOffset, maximumCandidateValue)
    }

    private func asPlayablePuzzle(difficulty: PuzzleDifficulty) -> PlayablePuzzle {
        let allNumberPoints = numberPoints()
        var givenPoints = sparseGivenNumberPoints(from: allNumberPoints, difficulty: difficulty)
        var givenOperatorPoints = sparseGivenOperatorPoints(
            difficulty: difficulty,
            givenNumberPoints: givenPoints,
            allNumberPoints: allNumberPoints
        )

        let requiredOperatorCards = difficulty.minimumHiddenOperatorCount(blockCount: blocks.count)
        let hiddenOperatorCount = operationPoints().count - givenOperatorPoints.count
        if hiddenOperatorCount < requiredOperatorCards {
            givenPoints = allNumberPoints
            givenOperatorPoints = sparseGivenOperatorPoints(
                difficulty: difficulty,
                givenNumberPoints: givenPoints,
                allNumberPoints: allNumberPoints
            )
        }

        return playablePuzzle(
            givenNumberPoints: givenPoints,
            allNumberPoints: allNumberPoints,
            givenOperatorPoints: givenOperatorPoints
        )
    }

    private func numberPoints() -> Set<GridPoint> {
        Set(blocks.flatMap { Self.numberPoints(for: $0) })
    }

    private func sparseGivenNumberPoints(
        from allNumberPoints: Set<GridPoint>,
        difficulty: PuzzleDifficulty
    ) -> Set<GridPoint> {
        let minimumGivenCount = minimumGivenNumberCount(for: difficulty)
        let maximumHiddenCount = maximumHiddenNumberCount(
            totalNumberCount: allNumberPoints.count,
            difficulty: difficulty
        )
        var givenPoints = allNumberPoints
        var hiddenValueCounts: [Int: Int] = [:]

        for duplicateLimit in hiddenDuplicateLimits(for: difficulty) {
            for point in removableNumberPoints(from: allNumberPoints, difficulty: difficulty) {
                guard givenPoints.contains(point) else {
                    continue
                }

                guard givenPoints.count > minimumGivenCount else {
                    break
                }

                guard allNumberPoints.count - givenPoints.count < maximumHiddenCount else {
                    break
                }

                guard
                    let valueText = cellContents[point],
                    let value = Int(valueText),
                    hiddenValueCounts[value, default: 0] < duplicateLimit
                else {
                    continue
                }

                let candidateGivenPoints = givenPoints.subtracting([point])
                let candidatePlayable = playablePuzzle(
                    givenNumberPoints: candidateGivenPoints,
                    allNumberPoints: allNumberPoints,
                    givenOperatorPoints: Set(operationPoints().keys)
                )

                if solutionCount(
                    using: candidatePlayable.answerCards,
                    operatorCards: candidatePlayable.operatorCards,
                    fixedValues: candidatePlayable.givenNumberValues,
                    fixedOperators: candidatePlayable.givenOperatorValues,
                    limit: 2
                ) == 1 {
                    givenPoints = candidateGivenPoints
                    hiddenValueCounts[value, default: 0] += 1
                }
            }
        }

        return givenPoints
    }

    private func hiddenDuplicateLimits(for difficulty: PuzzleDifficulty) -> [Int] {
        switch difficulty {
        case .beginner:
            return [2, 3]
        case .intermediate, .advanced, .expert:
            return [1, 2]
        }
    }

    private func minimumGivenNumberCount(for difficulty: PuzzleDifficulty) -> Int {
        switch difficulty {
        case .beginner:
            return max(2, blocks.count / 3)
        case .intermediate:
            return max(2, blocks.count / 4)
        case .advanced:
            return max(2, blocks.count / 4)
        case .expert:
            return 1
        }
    }

    private func maximumHiddenNumberCount(
        totalNumberCount: Int,
        difficulty: PuzzleDifficulty
    ) -> Int {
        let baseTarget: Int

        switch blocks.count {
        case 18...:
            baseTarget = 24
        case 17:
            baseTarget = 23
        case 16:
            baseTarget = 22
        case 15:
            baseTarget = 21
        case 11...:
            baseTarget = 20
        default:
            baseTarget = totalNumberCount
        }

        if difficulty == .advanced {
            return min(
                max(5, totalNumberCount * difficulty.hiddenCardRatioPercent / 100),
                max(totalNumberCount - minimumGivenNumberCount(for: difficulty), 0)
            )
        }

        if difficulty == .expert {
            return min(
                max(6, totalNumberCount * difficulty.hiddenCardRatioPercent / 100),
                max(totalNumberCount - minimumGivenNumberCount(for: difficulty), 0)
            )
        }

        let beginnerMinimumGivenCount = max(2, blocks.count / 3)
        let beginnerTarget = max(4, baseTarget + PuzzleDifficulty.beginner.hiddenTargetOffset)
        let beginnerRatioLimit = max(4, totalNumberCount * PuzzleDifficulty.beginner.hiddenCardRatioPercent / 100)
        let beginnerLimit = min(
            beginnerTarget,
            beginnerRatioLimit,
            max(totalNumberCount - beginnerMinimumGivenCount, 0)
        )

        if difficulty == .intermediate {
            let advancedLimit = max(totalNumberCount - 1, 0)
            let midpointLimit = (beginnerLimit + advancedLimit + 1) / 2
            let target = max(5, baseTarget + difficulty.hiddenTargetOffset)
            let ratioLimit = max(5, totalNumberCount * difficulty.hiddenCardRatioPercent / 100)

            return min(
                max(midpointLimit, ratioLimit),
                target,
                max(totalNumberCount - minimumGivenNumberCount(for: difficulty), 0)
            )
        }

        let target = max(4, baseTarget + difficulty.hiddenTargetOffset)
        let ratioLimit = max(4, totalNumberCount * difficulty.hiddenCardRatioPercent / 100)
        return min(target, ratioLimit, max(totalNumberCount - max(2, blocks.count / 3), 0))
    }

    private func removableNumberPoints(
        from allNumberPoints: Set<GridPoint>,
        difficulty: PuzzleDifficulty
    ) -> [GridPoint] {
        allNumberPoints.sorted { first, second in
            let firstScore = removalPriority(for: first, difficulty: difficulty)
            let secondScore = removalPriority(for: second, difficulty: difficulty)

            if firstScore == secondScore {
                if first.row == second.row {
                    return first.column < second.column
                }
                return first.row < second.row
            }

            return firstScore > secondScore
        }
    }

    private func removalPriority(for point: GridPoint, difficulty: PuzzleDifficulty) -> Int {
        let isSharedPoint = blocks(at: point).count > 1
        let sharedWeight: Int

        switch difficulty {
        case .beginner:
            sharedWeight = isSharedPoint ? 0 : 10
        case .intermediate:
            sharedWeight = isSharedPoint ? 7 : 5
        case .advanced, .expert:
            sharedWeight = isSharedPoint ? 14 : 0
        }

        let resultWeight = blocks(at: point).contains { block in
            Self.numberPoints(for: block).last == point
        } ? 4 : 0

        return sharedWeight + resultWeight
    }

    private func sparseGivenOperatorPoints(
        difficulty: PuzzleDifficulty,
        givenNumberPoints: Set<GridPoint>,
        allNumberPoints: Set<GridPoint>
    ) -> Set<GridPoint> {
        let allOperatorPoints = Set(operationPoints().keys)
        guard difficulty.hidesOperators else {
            return allOperatorPoints
        }

        let hiddenTarget = min(
            allOperatorPoints.count,
            max(difficulty.minimumHiddenOperatorCount(blockCount: blocks.count), min(blocks.count / 4, 4))
        )
        let minimumHiddenCount = difficulty.minimumHiddenOperatorCount(blockCount: blocks.count)

        for hiddenCount in stride(from: hiddenTarget, through: minimumHiddenCount, by: -1) {
            for hiddenOperatorPoints in hiddenOperatorPointSets(
                from: allOperatorPoints.sorted(by: gridPointSort),
                count: hiddenCount
            ) {
                guard allowsHiddenOperatorSet(hiddenOperatorPoints, hiddenCount: hiddenCount, difficulty: difficulty) else {
                    continue
                }

                let candidateGivenOperatorPoints = allOperatorPoints.subtracting(hiddenOperatorPoints)
                let candidatePlayable = playablePuzzle(
                    givenNumberPoints: givenNumberPoints,
                    allNumberPoints: allNumberPoints,
                    givenOperatorPoints: candidateGivenOperatorPoints
                )

                if solutionCount(
                    using: candidatePlayable.answerCards,
                    operatorCards: candidatePlayable.operatorCards,
                    fixedValues: candidatePlayable.givenNumberValues,
                    fixedOperators: candidatePlayable.givenOperatorValues,
                    limit: 2
                ) == 1 {
                    return candidateGivenOperatorPoints
                }
            }
        }

        return allOperatorPoints
    }

    private func allowsHiddenOperatorSet(
        _ hiddenOperatorPoints: Set<GridPoint>,
        hiddenCount: Int,
        difficulty: PuzzleDifficulty
    ) -> Bool {
        guard difficulty == .expert, hiddenCount == 2 else {
            return true
        }

        let operators = operationPoints()
        let hiddenOperators = hiddenOperatorPoints.compactMap { operators[$0] }
        return Set(hiddenOperators).count == hiddenOperators.count
    }

    private func hiddenOperatorPointSets(from points: [GridPoint], count: Int) -> [Set<GridPoint>] {
        guard count > 0 else {
            return [Set<GridPoint>()]
        }

        guard count <= points.count else {
            return []
        }

        var results: [Set<GridPoint>] = []
        var selected: [GridPoint] = []

        func search(startIndex: Int) {
            if selected.count == count {
                results.append(Set(selected))
                return
            }

            let remainingNeeded = count - selected.count
            let lastStart = points.count - remainingNeeded
            guard startIndex <= lastStart else {
                return
            }

            for index in startIndex...lastStart {
                selected.append(points[index])
                search(startIndex: index + 1)
                selected.removeLast()
            }
        }

        search(startIndex: 0)
        return results.shuffled()
    }

    private func playablePuzzle(
        givenNumberPoints: Set<GridPoint>,
        allNumberPoints: Set<GridPoint>,
        givenOperatorPoints: Set<GridPoint>
    ) -> PlayablePuzzle {
        let allOperatorPoints = Set(operationPoints().keys)
        let hiddenPoints = allNumberPoints.subtracting(givenNumberPoints).sorted(by: gridPointSort)
        let hiddenOperatorPoints = allOperatorPoints.subtracting(givenOperatorPoints).sorted(by: gridPointSort)
        let hiddenContentPoints = Set(hiddenPoints).union(hiddenOperatorPoints)
        let visibleContents = cellContents.filter { point, content in
            !hiddenContentPoints.contains(point) && !content.isEmpty
        }
        let answerCards = hiddenPoints.compactMap { point in
            Int(cellContents[point] ?? "")
        }.sorted()
        let operatorValues = operationPoints()
        let operatorCards = hiddenOperatorPoints.compactMap { point in
            operatorValues[point] ?? ArithmeticOperator(rawValue: cellContents[point] ?? "")
        }.sorted { $0.sortOrder < $1.sortOrder }
        let givenNumberValues = Dictionary(
            uniqueKeysWithValues: givenNumberPoints.compactMap { point -> (GridPoint, Int)? in
                guard let value = Int(cellContents[point] ?? "") else {
                    return nil
                }

                return (point, value)
            }
        )
        let givenOperatorValues = Dictionary(
            uniqueKeysWithValues: givenOperatorPoints.compactMap { point -> (GridPoint, ArithmeticOperator)? in
                guard let value = ArithmeticOperator(rawValue: cellContents[point] ?? "") else {
                    return nil
                }

                return (point, value)
            }
        )

        return PlayablePuzzle(
            solution: self,
            visibleContents: visibleContents,
            answerCards: answerCards,
            operatorCards: operatorCards,
            hiddenNumberPoints: hiddenPoints,
            hiddenOperatorPoints: hiddenOperatorPoints,
            givenNumberValues: givenNumberValues,
            givenOperatorValues: givenOperatorValues
        )
    }

    private func gridPointSort(_ first: GridPoint, _ second: GridPoint) -> Bool {
        if first.row == second.row {
            return first.column < second.column
        }
        return first.row < second.row
    }

    private func operationPoints() -> [GridPoint: ArithmeticOperator] {
        Dictionary(
            uniqueKeysWithValues: blocks.compactMap { block -> (GridPoint, ArithmeticOperator)? in
                guard let operation = equations[block.id]?.operation else {
                    return nil
                }

                return (block.cells[1], operation)
            }
        )
    }

    private func oldPlayablePuzzle(givenPoints: Set<GridPoint>, allNumberPoints: Set<GridPoint>) -> PlayablePuzzle {
        let hiddenPoints = allNumberPoints.subtracting(givenPoints).sorted {
            if $0.row == $1.row {
                return $0.column < $1.column
            }
            return $0.row < $1.row
        }
        let visibleContents = cellContents.filter { point, content in
            (!allNumberPoints.contains(point) || givenPoints.contains(point)) && !content.isEmpty
        }
        let answerCards = hiddenPoints.compactMap { point in
            Int(cellContents[point] ?? "")
        }.sorted()
        let givenNumberValues = Dictionary(
            uniqueKeysWithValues: givenPoints.compactMap { point -> (GridPoint, Int)? in
                guard let value = Int(cellContents[point] ?? "") else {
                    return nil
                }

                return (point, value)
            }
        )

        return PlayablePuzzle(
            solution: self,
            visibleContents: visibleContents,
            answerCards: answerCards,
            operatorCards: [],
            hiddenNumberPoints: hiddenPoints,
            hiddenOperatorPoints: [],
            givenNumberValues: givenNumberValues,
            givenOperatorValues: [:]
        )
    }

    private func isValid(expectedBlockCount: Int) -> Bool {
        guard blocks.count == expectedBlockCount else { return false }
        guard blocks.allSatisfy({ block in
            block.cells.allSatisfy { point in
                (0..<size).contains(point.row) && (0..<size).contains(point.column)
            }
        }) else {
            return false
        }

        guard blocks.allSatisfy({ block in
            let count = connectionCounts[block.id, default: 0]
            return (1...3).contains(count)
        }) else {
            return false
        }

        let indexedBlocks = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        for connection in connections {
            guard
                let first = indexedBlocks[connection.firstBlockID],
                let second = indexedBlocks[connection.secondBlockID],
                first.orientation != second.orientation,
                connection.firstPoint == connection.secondPoint,
                first.hasConnector(at: connection.firstPoint),
                second.hasConnector(at: connection.secondPoint)
            else {
                return false
            }
        }

        let cells = Dictionary(grouping: blocks.flatMap { block in
            block.cells.map { (point: $0, block: block) }
        }, by: \.point)

        return cells.values.allSatisfy { occupants in
            guard occupants.count > 1 else { return true }
            guard occupants.count == 2 else { return false }

            let first = occupants[0].block
            let second = occupants[1].block
            let point = occupants[0].point

            return first.orientation != second.orientation
                && first.hasConnector(at: point)
                && second.hasConnector(at: point)
        }
    }

    private static func buildCandidate(blockCount: Int, size: Int) -> BoardPuzzle? {
        var blocks: [BoardBlock] = []
        var connections: [BlockConnection] = []

        guard let first = randomBlock(id: 1, size: size, occupied: []) else {
            return nil
        }
        blocks.append(first)

        while blocks.count < blockCount {
            let nextID = blocks.count + 1
            let counts = connectionCounts(for: blocks, connections: connections)
            let candidates = placementCandidates(id: nextID, size: size)
                .compactMap { candidate -> (block: BoardBlock, links: [(BoardBlock, GridPoint)])? in
                    let links = sharedConnectorLinks(from: candidate, to: blocks, counts: counts)
                    return links.isEmpty ? nil : (candidate, links)
                }

            guard let choice = candidates.randomElement() else {
                return nil
            }

            blocks.append(choice.block)
            connections.append(
                contentsOf: choice.links.map { link in
                    BlockConnection(
                        firstBlockID: link.0.id,
                        firstPoint: link.1,
                        secondBlockID: choice.block.id,
                        secondPoint: link.1
                    )
                }
            )
        }

        return BoardPuzzle(size: size, blocks: blocks, connections: connections, cellContents: [:], equations: [:])
    }

    private static func placementCandidates(id: Int, size: Int) -> [BoardBlock] {
        var results: [BoardBlock] = []

        for orientation in BlockOrientation.allCases {
            let maxRow = orientation == .vertical ? size - BoardBlock.length : size - 1
            let maxColumn = orientation == .horizontal ? size - BoardBlock.length : size - 1

            for row in 0...maxRow {
                for column in 0...maxColumn {
                    for slots in connectorSlotOptions().shuffled() {
                        let block = BoardBlock(
                            id: id,
                            orientation: orientation,
                            origin: GridPoint(row: row, column: column),
                            connectorSlots: slots
                        )
                        results.append(block)
                    }
                }
            }
        }

        return results.shuffled()
    }

    private static func randomBlock(id: Int, size: Int, occupied: Set<GridPoint>) -> BoardBlock? {
        placementCandidates(id: id, size: size)
            .filter { occupied.isDisjoint(with: $0.cells) }
            .randomElement()
    }

    private static func connectorSlotOptions() -> [Set<Int>] {
        let slots = Array(BoardBlock.connectableSlots)
        var options: [Set<Int>] = []

        for mask in 1..<(1 << slots.count) {
            let selected = slots.enumerated().compactMap { bit, slot in
                (mask & (1 << bit)) == 0 ? nil : slot
            }
            if (1...3).contains(selected.count) {
                options.append(Set(selected))
            }
        }

        return options
    }

    private static func sharedConnectorLinks(
        from candidate: BoardBlock,
        to blocks: [BoardBlock],
        counts: [Int: Int]
    ) -> [(BoardBlock, GridPoint)] {
        var links: [(BoardBlock, GridPoint)] = []
        let existingCells = Dictionary(grouping: blocks.flatMap { block in
            block.cells.map { (point: $0, block: block) }
        }, by: \.point)

        for point in candidate.cells {
            guard let occupants = existingCells[point] else {
                continue
            }

            guard candidate.hasConnector(at: point), occupants.count == 1 else {
                return []
            }

            let existing = occupants[0].block
            guard existing.orientation != candidate.orientation else {
                return []
            }

            guard existing.hasConnector(at: point), counts[existing.id, default: 0] < 3 else {
                return []
            }

            links.append((existing, point))
        }

        guard (1...3).contains(links.count) else {
            return []
        }

        let projectedCounts = Dictionary(grouping: links, by: { $0.0.id })
        guard projectedCounts.allSatisfy({ blockID, blockLinks in
            counts[blockID, default: 0] + blockLinks.count <= 3
        }) else {
            return []
        }

        return links
    }

    private static func connectionCounts(
        for blocks: [BoardBlock],
        connections: [BlockConnection]
    ) -> [Int: Int] {
        var counts = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, 0) })
        for connection in connections {
            counts[connection.firstBlockID, default: 0] += 1
            counts[connection.secondBlockID, default: 0] += 1
        }
        return counts
    }

    private func withAssignedEquations(
        minimumNumberValue: Int,
        maximumNumberValue: Int,
        difficulty: PuzzleDifficulty
    ) -> BoardPuzzle? {
        guard let assignment = Self.assignEquations(
            to: blocks,
            minimumNumberValue: minimumNumberValue,
            maximumNumberValue: maximumNumberValue,
            difficulty: difficulty
        ) else {
            return nil
        }

        var contents: [GridPoint: String] = [:]

        for block in blocks {
            guard let equation = assignment.equations[block.id] else {
                return nil
            }

            let cells = block.cells
            contents[cells[0]] = "\(equation.lhs)"
            contents[cells[1]] = equation.operation.rawValue
            contents[cells[2]] = "\(equation.rhs)"
            contents[cells[3]] = "＝"
            contents[cells[4]] = "\(equation.result)"
        }

        return BoardPuzzle(
            size: size,
            blocks: blocks,
            connections: connections,
            cellContents: contents,
            equations: assignment.equations
        )
    }

    private static func assignEquations(
        to blocks: [BoardBlock],
        minimumNumberValue: Int,
        maximumNumberValue: Int,
        difficulty: PuzzleDifficulty
    ) -> (equations: [Int: BlockEquation], values: [GridPoint: Int])? {
        let candidates = cachedEquationCandidates.filter { candidate in
            (minimumNumberValue...maximumNumberValue).contains(candidate.lhs) &&
                (minimumNumberValue...maximumNumberValue).contains(candidate.rhs) &&
                (minimumNumberValue...maximumNumberValue).contains(candidate.result)
        }
        let orderedCandidates = orderedEquationCandidates(
            candidates,
            maximumNumberValue: maximumNumberValue,
            difficulty: difficulty
        )

        func solve(
            remaining: [BoardBlock],
            values: [GridPoint: Int],
            equations: [Int: BlockEquation]
        ) -> (equations: [Int: BlockEquation], values: [GridPoint: Int])? {
            guard !remaining.isEmpty else {
                return (equations, values)
            }

            let selected = remaining.max { first, second in
                let firstAssigned = numberPoints(for: first).filter { values[$0] != nil }.count
                let secondAssigned = numberPoints(for: second).filter { values[$0] != nil }.count
                return firstAssigned < secondAssigned
            }!

            let nextRemaining = remaining.filter { $0.id != selected.id }
            let points = numberPoints(for: selected)
            let candidatesForSelectedBlock = orderedCandidatesForAssignment(
                orderedCandidates,
                points: points,
                values: values,
                minimumNumberValue: minimumNumberValue,
                maximumNumberValue: maximumNumberValue,
                difficulty: difficulty
            )

            for candidate in candidatesForSelectedBlock {
                let candidateValues = [candidate.lhs, candidate.rhs, candidate.result]
                var nextValues = values
                var fits = true

                for index in 0..<points.count {
                    let point = points[index]
                    let value = candidateValues[index]

                    if let existing = nextValues[point], existing != value {
                        fits = false
                        break
                    }

                    nextValues[point] = value
                }

                guard fits else { continue }

                var nextEquations = equations
                nextEquations[selected.id] = candidate

                if let solved = solve(
                    remaining: nextRemaining,
                    values: nextValues,
                    equations: nextEquations
                ) {
                    return solved
                }
            }

            return nil
        }

        return solve(remaining: blocks, values: [:], equations: [:])
    }

    private static func orderedCandidatesForAssignment(
        _ candidates: [BlockEquation],
        points: [GridPoint],
        values: [GridPoint: Int],
        minimumNumberValue: Int,
        maximumNumberValue: Int,
        difficulty: PuzzleDifficulty
    ) -> [BlockEquation] {
        guard difficulty == .intermediate || difficulty == .advanced || difficulty == .expert else {
            return candidates
        }

        return candidates.sorted { first, second in
            let firstScore = assignmentDiversityScore(
                first,
                points: points,
                values: values,
                minimumNumberValue: minimumNumberValue,
                maximumNumberValue: maximumNumberValue,
                difficulty: difficulty
            )
            let secondScore = assignmentDiversityScore(
                second,
                points: points,
                values: values,
                minimumNumberValue: minimumNumberValue,
                maximumNumberValue: maximumNumberValue,
                difficulty: difficulty
            )

            if firstScore == secondScore {
                return first.operation.sortOrder > second.operation.sortOrder
            }

            return firstScore > secondScore
        }
    }

    private static func assignmentDiversityScore(
        _ equation: BlockEquation,
        points: [GridPoint],
        values: [GridPoint: Int],
        minimumNumberValue: Int,
        maximumNumberValue: Int,
        difficulty: PuzzleDifficulty
    ) -> Int {
        let candidateValues = [equation.lhs, equation.rhs, equation.result]
        let currentValueCounts = Dictionary(grouping: values.values, by: { $0 }).mapValues(\.count)
        let candidateValueCounts = Dictionary(grouping: candidateValues, by: { $0 }).mapValues(\.count)
        let distinctCount = Set(candidateValues).count
        let lowValueThreshold = minimumNumberValue + 3
        var score = difficulty == .expert
            ? expertEquationScore(equation, maximumNumberValue: maximumNumberValue)
            : candidateValues.reduce(0, +)

        score += distinctCount * 1_600
        score += Set(candidateValues).filter { currentValueCounts[$0, default: 0] == 0 }.count * 1_200
        score += abs(equation.lhs - equation.rhs) * 8

        for (index, point) in points.enumerated() {
            let value = candidateValues[index]

            if let existing = values[point] {
                if existing == value {
                    score += 120
                }
                continue
            }

            score -= currentValueCounts[value, default: 0] * 1_400
            score -= max(candidateValueCounts[value, default: 0] - 1, 0) * 1_100

            if value <= lowValueThreshold {
                score -= (lowValueThreshold - value + 1) * 260
            }
        }

        return score
    }

    private static func numberPoints(for block: BoardBlock) -> [GridPoint] {
        let cells = block.cells
        return [cells[0], cells[2], cells[4]]
    }

    private static func orderedEquationCandidates(
        _ candidates: [BlockEquation],
        maximumNumberValue: Int,
        difficulty: PuzzleDifficulty
    ) -> [BlockEquation] {
        guard difficulty == .expert else {
            return candidates.shuffled()
        }

        return candidates.shuffled().sorted { first, second in
            let firstScore = expertEquationScore(first, maximumNumberValue: maximumNumberValue)
            let secondScore = expertEquationScore(second, maximumNumberValue: maximumNumberValue)

            if firstScore == secondScore {
                return first.operation.sortOrder > second.operation.sortOrder
            }

            return firstScore > secondScore
        }
    }

    private static func expertEquationScore(
        _ equation: BlockEquation,
        maximumNumberValue: Int
    ) -> Int {
        let highValueThreshold = max(2, maximumNumberValue * 2 / 3)
        let values = [equation.lhs, equation.rhs, equation.result]
        let highValueCount = values.filter { $0 >= highValueThreshold }.count
        let largestValue = values.max() ?? 0
        let totalValue = values.reduce(0, +)
        let operationWeight: Int

        switch equation.operation {
        case .multiply:
            operationWeight = 900
        case .divide:
            operationWeight = 820
        case .subtract:
            operationWeight = 280
        case .add:
            operationWeight = 180
        }

        return operationWeight +
            highValueCount * 260 +
            largestValue * 5 +
            totalValue +
            abs(equation.lhs - equation.rhs)
    }

    private func solutionCount(
        using cards: [Int],
        operatorCards: [ArithmeticOperator],
        fixedValues: [GridPoint: Int],
        fixedOperators: [GridPoint: ArithmeticOperator],
        limit: Int
    ) -> Int {
        let allNumberPoints = numberPoints()
        let allOperatorPoints = Set(operationPoints().keys)
        var initialCards: [Int: Int] = [:]
        var initialOperatorCards: [ArithmeticOperator: Int] = [:]

        for card in cards {
            initialCards[card, default: 0] += 1
        }

        for card in operatorCards {
            initialOperatorCards[card, default: 0] += 1
        }

        func isEquationSatisfied(
            _ block: BoardBlock,
            values: [GridPoint: Int],
            operators: [GridPoint: ArithmeticOperator]
        ) -> Bool? {
            let points = Self.numberPoints(for: block)
            guard
                let lhs = values[points[0]],
                let rhs = values[points[1]],
                let result = values[points[2]]
            else {
                return nil
            }

            guard let operation = operators[block.cells[1]] else {
                return nil
            }

            return operation.apply(lhs, rhs) == result
        }

        func viableAssignments(
            for block: BoardBlock,
            values: [GridPoint: Int],
            operators: [GridPoint: ArithmeticOperator],
            remainingCards: [Int: Int],
            remainingOperatorCards: [ArithmeticOperator: Int]
        ) -> [(values: [GridPoint: Int], operators: [GridPoint: ArithmeticOperator], cards: [Int: Int], operatorCards: [ArithmeticOperator: Int])] {
            let points = Self.numberPoints(for: block)
            let operatorPoint = block.cells[1]
            let candidates: [BlockEquation]

            if let operation = operators[operatorPoint] {
                candidates = Self.cachedCandidatesByOperator[operation] ?? []
            } else {
                candidates = Self.cachedEquationCandidates
            }

            var results: [(values: [GridPoint: Int], operators: [GridPoint: ArithmeticOperator], cards: [Int: Int], operatorCards: [ArithmeticOperator: Int])] = []

            for candidate in candidates {
                let candidateValues = [candidate.lhs, candidate.rhs, candidate.result]
                var nextValues = values
                var nextOperators = operators
                var cardsNeeded: [Int: Int] = [:]
                var fits = true

                if let assignedOperation = nextOperators[operatorPoint] {
                    guard assignedOperation == candidate.operation else {
                        continue
                    }
                } else {
                    nextOperators[operatorPoint] = candidate.operation
                }

                for index in 0..<points.count {
                    let point = points[index]
                    let value = candidateValues[index]

                    if let assigned = nextValues[point] {
                        if assigned != value {
                            fits = false
                            break
                        }
                    } else {
                        nextValues[point] = value
                        cardsNeeded[value, default: 0] += 1
                    }
                }

                guard fits else { continue }

                var nextCards = remainingCards
                var nextOperatorCards = remainingOperatorCards
                for (value, count) in cardsNeeded {
                    guard nextCards[value, default: 0] >= count else {
                        fits = false
                        break
                    }
                    nextCards[value, default: 0] -= count
                }

                guard fits else { continue }

                if operators[operatorPoint] == nil {
                    guard nextOperatorCards[candidate.operation, default: 0] > 0 else {
                        continue
                    }
                    nextOperatorCards[candidate.operation, default: 0] -= 1
                }

                results.append((nextValues, nextOperators, nextCards, nextOperatorCards))
            }

            return results
        }

        func solve(
            values: [GridPoint: Int],
            operators: [GridPoint: ArithmeticOperator],
            remainingCards: [Int: Int],
            remainingOperatorCards: [ArithmeticOperator: Int],
            found: inout Int
        ) {
            guard found < limit else { return }

            for block in blocks {
                if isEquationSatisfied(block, values: values, operators: operators) == false {
                    return
                }
            }

            if allNumberPoints.allSatisfy({ values[$0] != nil }) &&
                allOperatorPoints.allSatisfy({ operators[$0] != nil }) {
                found += 1
                return
            }

            let pendingBlocks = blocks.filter { block in
                Self.numberPoints(for: block).contains { values[$0] == nil } ||
                    operators[block.cells[1]] == nil
            }

            var selectedAssignments: [(values: [GridPoint: Int], operators: [GridPoint: ArithmeticOperator], cards: [Int: Int], operatorCards: [ArithmeticOperator: Int])]?

            for block in pendingBlocks {
                let assignments = viableAssignments(
                    for: block,
                    values: values,
                    operators: operators,
                    remainingCards: remainingCards,
                    remainingOperatorCards: remainingOperatorCards
                )

                if assignments.isEmpty {
                    return
                }

                if selectedAssignments == nil || assignments.count < selectedAssignments!.count {
                    selectedAssignments = assignments

                    if assignments.count == 1 {
                        break
                    }
                }
            }

            guard let selectedAssignments else {
                return
            }

            for assignment in selectedAssignments {
                solve(
                    values: assignment.values,
                    operators: assignment.operators,
                    remainingCards: assignment.cards,
                    remainingOperatorCards: assignment.operatorCards,
                    found: &found
                )
                if found >= limit {
                    return
                }
            }
        }

        var found = 0
        solve(
            values: fixedValues,
            operators: fixedOperators,
            remainingCards: initialCards,
            remainingOperatorCards: initialOperatorCards,
            found: &found
        )
        return found
    }

    private static func makeEquationCandidates(maxValue: Int) -> [BlockEquation] {
        let values = 1...maxValue
        var candidates: [BlockEquation] = []

        for lhs in values {
            for rhs in values {
                for operation in ArithmeticOperator.allCases {
                    guard let result = operation.apply(lhs, rhs), values.contains(result) else {
                        continue
                    }

                    candidates.append(
                        BlockEquation(
                            lhs: lhs,
                            operation: operation,
                            rhs: rhs,
                            result: result
                        )
                    )
                }
            }
        }

        return candidates
    }

    private static func fallback(blockCount: Int, size: Int) -> BoardPuzzle {
        let allBlocks = [
            BoardBlock(id: 1, orientation: .vertical, origin: GridPoint(row: 6, column: 8), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 2, orientation: .horizontal, origin: GridPoint(row: 6, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 3, orientation: .vertical, origin: GridPoint(row: 2, column: 10), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 4, orientation: .horizontal, origin: GridPoint(row: 8, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 5, orientation: .horizontal, origin: GridPoint(row: 4, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 6, orientation: .vertical, origin: GridPoint(row: 6, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 7, orientation: .horizontal, origin: GridPoint(row: 2, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 8, orientation: .horizontal, origin: GridPoint(row: 10, column: 2), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 9, orientation: .vertical, origin: GridPoint(row: 6, column: 2), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 10, orientation: .vertical, origin: GridPoint(row: 6, column: 4), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 11, orientation: .vertical, origin: GridPoint(row: 0, column: 8), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 12, orientation: .vertical, origin: GridPoint(row: 0, column: 6), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 13, orientation: .horizontal, origin: GridPoint(row: 0, column: 2), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 14, orientation: .horizontal, origin: GridPoint(row: 6, column: 0), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 15, orientation: .vertical, origin: GridPoint(row: 4, column: 0), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 16, orientation: .horizontal, origin: GridPoint(row: 4, column: 0), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 17, orientation: .horizontal, origin: GridPoint(row: 8, column: 0), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 18, orientation: .vertical, origin: GridPoint(row: 0, column: 2), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 19, orientation: .horizontal, origin: GridPoint(row: 2, column: 0), connectorSlots: [0, 2, 4]),
            BoardBlock(id: 20, orientation: .vertical, origin: GridPoint(row: 0, column: 4), connectorSlots: [0, 2, 4])
        ]

        let count = min(max(blockCount, blockCountRange.lowerBound), blockCountRange.upperBound)
        let blocks = Array(allBlocks.prefix(count))
        var placed: [BoardBlock] = []
        var connections: [BlockConnection] = []

        for block in blocks {
            let counts = connectionCounts(for: placed, connections: connections)
            let links = sharedConnectorLinks(from: block, to: placed, counts: counts)

            connections.append(
                contentsOf: links.map { link in
                    BlockConnection(
                        firstBlockID: link.0.id,
                        firstPoint: link.1,
                        secondBlockID: block.id,
                        secondPoint: link.1
                    )
                }
            )
            placed.append(block)
        }

        return BoardPuzzle(size: size, blocks: placed, connections: connections, cellContents: [:], equations: [:])
    }
}

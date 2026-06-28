import AudioToolbox
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var level: Int
    @State private var blockCount: Int
    @State private var difficulty: PuzzleDifficulty
    @State private var puzzle: PlayablePuzzle
    @State private var placedCards: [GridPoint: PlacedCard] = [:]
    @State private var placedOperatorCards: [GridPoint: PlacedOperatorCard] = [:]
    @State private var selectedCardIndex: Int?
    @State private var selectedOperatorCardIndex: Int?
    @State private var hintPoints: Int
    @State private var isSoundEnabled: Bool
    @State private var hintedNumberPoints: Set<GridPoint> = []
    @State private var showConfetti = false
    @State private var celebrationID = 0
    @State private var hasCelebratedCurrentPuzzle = false
    @State private var solvedCounts: [String: Int]
    @State private var completedPuzzleIDs: [Int: Set<Int>]
    @State private var currentPreparedPuzzleID: Int?
    @State private var unlockMessage: String?
    @State private var celebrationUnlockMessage: String?
    @State private var celebrationEncouragementMessage: String?
    @State private var clearProgressMessage: String?
    @State private var nextUnlockedPuzzleKey: PuzzleCacheKey?
    @State private var showNextPuzzleButton = false
    @State private var showResetAchievementsDialog = false
    @State private var resetAchievementLevelText = ""
    @State private var showHintConfirmDialog = false
    @State private var showHintGrantDialog = false
    @State private var hintGrantText = "1"
    @State private var showReplacePuzzleConfirmDialog = false
    @State private var showHowToPlaySheet = false
    @State private var snappingPlacedPoints: Set<GridPoint> = []

    private let appVersion = "0.8.2"
    private let cellSpacing: CGFloat = 2
    private let ink = Color(red: 0.12, green: 0.15, blue: 0.18)
    private let accent = Color(red: 0.04, green: 0.45, blue: 0.39)
    private let heartAccent = Color(red: 0.92, green: 0.08, blue: 0.16)
    private let selectedAccent = Color(red: 0.95, green: 0.72, blue: 0.24)
    private let errorAccent = Color(red: 0.86, green: 0.13, blue: 0.16)
    private let backgroundTop = Color(red: 0.66, green: 0.47, blue: 0.28)
    private let backgroundBottom = Color(red: 0.36, green: 0.23, blue: 0.14)
    private let panelTop = Color(red: 0.82, green: 0.60, blue: 0.34)
    private let panelBottom = Color(red: 0.55, green: 0.36, blue: 0.20)
    private let operatorFill = Color(red: 0.90, green: 0.86, blue: 0.78)
    private let givenFill = Color(red: 0.95, green: 0.92, blue: 0.84)
    private let emptyFill = Color(red: 0.57, green: 0.38, blue: 0.22)
    private let placedFill = Color(red: 0.95, green: 0.66, blue: 0.50)
    private let cardFill = Color(red: 0.95, green: 0.66, blue: 0.50)
    private let panelRadius: CGFloat = 10
    private static let solvedCountsKey = "mathCross.solvedCountsByBlockCount"
    private static let currentLevelKey = "mathCross.currentLevel"
    private static let completedPuzzleIDsKey = "mathCross.completedPuzzleIDsByLevel"
    private static let hintPointsKey = "mathCross.hintPoints"
    private static let soundEnabledKey = "mathCross.soundEnabled"
    private static let maximumHintPoints = 20
    private static var grandClearMessage: String {
        L10n.text("grand.clear.message")
    }
    private static let preparedPuzzleKeysByLevel: [Int: PuzzleCacheKey] = {
        let keys = PreparedPuzzleCatalog.shared.levelKeys()
        guard !keys.isEmpty else {
            let fallback = PuzzleCacheKey(
                level: 1,
                blockCount: BoardPuzzle.defaultBlockCount,
                difficulty: .beginner
            )
            return [fallback.level: fallback]
        }

        return Dictionary(uniqueKeysWithValues: keys.map { ($0.level, $0) })
    }()
    private static var availableLevelNumbers: [Int] {
        preparedPuzzleKeysByLevel.keys.sorted()
    }
    private static var lastLevelNumber: Int {
        availableLevelNumbers.last ?? 1
    }
    private static var encouragementMessages: [String] {
        (1...12).map { L10n.text("encouragement.\($0)") }
    }

    init() {
        let storedSolvedCounts = Self.loadSolvedCounts()
        var storedCompletedPuzzleIDs = Self.loadCompletedPuzzleIDs()
        let storedPuzzleKey = Self.loadCurrentPuzzleKey(solvedCounts: storedSolvedCounts)
        let initialPuzzle = Self.initialPlayablePuzzle(
            for: storedPuzzleKey,
            completedPuzzleIDs: &storedCompletedPuzzleIDs
        )

        _level = State(initialValue: storedPuzzleKey.level)
        _blockCount = State(initialValue: storedPuzzleKey.blockCount)
        _difficulty = State(initialValue: storedPuzzleKey.difficulty)
        _puzzle = State(initialValue: initialPuzzle.puzzle)
        _solvedCounts = State(initialValue: storedSolvedCounts)
        _completedPuzzleIDs = State(initialValue: storedCompletedPuzzleIDs)
        _currentPreparedPuzzleID = State(initialValue: initialPuzzle.puzzleID)
        _hintPoints = State(initialValue: Self.loadHintPoints())
        _isSoundEnabled = State(initialValue: Self.loadSoundEnabled())
    }

    private var boardSize: Int {
        puzzle.solution.size
    }

    private var currentSolvedCount: Int {
        clearCount(for: currentPuzzleKey)
    }

    private var currentClearRequirement: Int {
        clearRequirement(for: currentPuzzleKey)
    }

    private var currentLevelNumber: Int {
        level
    }

    private var currentPuzzleKey: PuzzleCacheKey {
        puzzleKey(forLevel: level) ?? PuzzleCacheKey(level: level, blockCount: blockCount, difficulty: difficulty)
    }

    private var nextLevelKey: PuzzleCacheKey? {
        nextPuzzleKey(after: currentPuzzleKey)
    }

    private var maximumLevelNumber: Int {
        Self.lastLevelNumber
    }

    private var levelProgress: Double {
        let levels = Self.availableLevelNumbers
        guard
            let index = levels.firstIndex(of: level),
            levels.count > 1
        else {
            return 0
        }

        return min(Double(index) / Double(levels.count - 1), 1)
    }

    private var backgroundTheme: BackgroundTheme {
        switch levelProgress {
        case ..<0.18:
            return BackgroundTheme(
                baseColors: [
                    Color(red: 0.80, green: 0.84, blue: 0.80),
                    Color(red: 0.61, green: 0.70, blue: 0.65)
                ],
                accentColors: [
                    Color(red: 0.83, green: 0.88, blue: 0.80),
                    Color(red: 0.66, green: 0.76, blue: 0.70)
                ],
                lineColor: Color.white,
                bandOpacity: 0.10,
                lineOpacity: 0.08,
                bandCount: 1
            )
        case ..<0.38:
            return BackgroundTheme(
                baseColors: [
                    Color(red: 0.76, green: 0.88, blue: 0.83),
                    Color(red: 0.33, green: 0.58, blue: 0.55)
                ],
                accentColors: [
                    Color(red: 0.95, green: 0.79, blue: 0.35),
                    Color(red: 0.22, green: 0.67, blue: 0.60)
                ],
                lineColor: Color(red: 0.96, green: 0.93, blue: 0.78),
                bandOpacity: 0.18,
                lineOpacity: 0.11,
                bandCount: 2
            )
        case ..<0.62:
            return BackgroundTheme(
                baseColors: [
                    Color(red: 0.77, green: 0.86, blue: 0.78),
                    Color(red: 0.12, green: 0.43, blue: 0.41),
                    Color(red: 0.64, green: 0.44, blue: 0.35)
                ],
                accentColors: [
                    Color(red: 0.98, green: 0.76, blue: 0.26),
                    Color(red: 0.84, green: 0.31, blue: 0.25),
                    Color(red: 0.13, green: 0.60, blue: 0.52)
                ],
                lineColor: Color(red: 1.00, green: 0.88, blue: 0.50),
                bandOpacity: 0.24,
                lineOpacity: 0.15,
                bandCount: 3
            )
        case ..<0.82:
            return BackgroundTheme(
                baseColors: [
                    Color(red: 0.90, green: 0.80, blue: 0.55),
                    Color(red: 0.15, green: 0.43, blue: 0.36),
                    Color(red: 0.47, green: 0.25, blue: 0.39)
                ],
                accentColors: [
                    Color(red: 1.00, green: 0.86, blue: 0.32),
                    Color(red: 0.87, green: 0.30, blue: 0.28),
                    Color(red: 0.14, green: 0.62, blue: 0.54)
                ],
                lineColor: Color(red: 1.00, green: 0.92, blue: 0.56),
                bandOpacity: 0.30,
                lineOpacity: 0.18,
                bandCount: 4
            )
        default:
            return BackgroundTheme(
                baseColors: [
                    Color(red: 0.96, green: 0.78, blue: 0.30),
                    Color(red: 0.12, green: 0.36, blue: 0.32),
                    Color(red: 0.50, green: 0.16, blue: 0.28),
                    Color(red: 0.91, green: 0.53, blue: 0.23)
                ],
                accentColors: [
                    Color(red: 1.00, green: 0.90, blue: 0.38),
                    Color(red: 0.95, green: 0.36, blue: 0.23),
                    Color(red: 0.19, green: 0.70, blue: 0.58)
                ],
                lineColor: Color(red: 1.00, green: 0.94, blue: 0.62),
                bandOpacity: 0.36,
                lineOpacity: 0.22,
                bandCount: 5
            )
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: boardSize)
    }

    var body: some View {
        ZStack {
            appBackground

            GeometryReader { geometry in
                let layoutScale = min(
                    max(min(geometry.size.width / 820, geometry.size.height / 1120), 0.82),
                    1.12
                )
                let sizeScale = min(
                    max(min(geometry.size.width / 820, geometry.size.height / 900), 0.90),
                    1.28
                )
                let horizontalPadding = max(8, min(18, geometry.size.width * 0.014))
                let verticalPadding = max(8, min(16, geometry.size.height * 0.010))
                let contentSpacing = max(8, min(18, 10 * layoutScale))
                let totalCardCount = puzzle.answerCards.count + puzzle.operatorCards.count
                let cardSpacing = max(6, min(14, totalCardCount >= 28 ? 8 * layoutScale : 10 * layoutScale))
                let trayPadding = max(6, min(14, totalCardCount >= 28 ? 8 * layoutScale : 10 * layoutScale))
                let maximumContentWidth = geometry.size.width - horizontalPadding * 2
                let contentWidth = min(maximumContentWidth, 860 * sizeScale)
                let headerReservedHeight = max(92, 98 * layoutScale)
                let cardScale = min(sizeScale, 1.10)
                let targetCardRows: Int = {
                    if totalCardCount >= 25 {
                        return 3
                    }
                    if totalCardCount >= 13 {
                        return 2
                    }
                    return 1
                }()
                let targetCardsPerRow = max(Int(ceil(Double(totalCardCount) / Double(targetCardRows))), 1)
                let cardSizeRange: ClosedRange<CGFloat> = totalCardCount >= 25 ? 46...(58 * cardScale) : 52...(72 * cardScale)
                let estimatedCardSide = max(
                    cardSizeRange.lowerBound,
                    min(
                        cardSizeRange.upperBound,
                        (contentWidth - trayPadding * 2 - CGFloat(targetCardsPerRow - 1) * cardSpacing) / CGFloat(targetCardsPerRow)
                    )
                )
                let cardsPerRow = max(
                    targetCardsPerRow,
                    Int((contentWidth - trayPadding * 2 + cardSpacing) / (estimatedCardSide + cardSpacing))
                )
                let cardSide = max(
                    cardSizeRange.lowerBound,
                    min(
                        cardSizeRange.upperBound,
                        (contentWidth - trayPadding * 2 - CGFloat(cardsPerRow - 1) * cardSpacing) / CGFloat(cardsPerRow)
                    )
                )
                let cardRows = CGFloat((totalCardCount + cardsPerRow - 1) / cardsPerRow)
                let trayHeight = cardRows * cardSide + max(cardRows - 1, 0) * cardSpacing + trayPadding * 2
                let reservedHeight = headerReservedHeight + trayHeight + contentSpacing * 2 + verticalPadding * 2
                let availableBoardSide = geometry.size.height - reservedHeight
                let minimumBoardSide = min(360 * sizeScale, contentWidth)
                let side = max(minimumBoardSide, min(contentWidth, availableBoardSide))

                VStack(spacing: contentSpacing) {
                    header

                    board(side: side)

                    cardTray(width: contentWidth, cardSide: cardSide, spacing: cardSpacing, padding: trayPadding)
                }
                .frame(
                    width: maximumContentWidth,
                    height: geometry.size.height - verticalPadding * 2,
                    alignment: .top
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .clipped()
            }

            if showConfetti {
                ConfettiBurst(trigger: celebrationID)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if let celebrationUnlockMessage {
                unlockCelebration(
                    message: celebrationUnlockMessage,
                    encouragement: celebrationEncouragementMessage,
                    nextKey: nextUnlockedPuzzleKey
                )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            if showNextPuzzleButton {
                nextPuzzlePrompt
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

        }
        .alert(
            L10n.text("achievement.reset.title"),
            isPresented: $showResetAchievementsDialog,
        ) {
            TextField(L10n.text("achievement.reset.field"), text: $resetAchievementLevelText)
                .keyboardType(.numberPad)

            Button(L10n.text("button.execute"), role: .destructive) {
                resetAchievements(through: Int(resetAchievementLevelText) ?? 0)
            }
            Button(L10n.text("button.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("achievement.reset.message"))
        }
        .alert(
            L10n.text("hint.use.title"),
            isPresented: $showHintConfirmDialog
        ) {
            Button(L10n.text("button.use")) {
                revealRandomHint()
            }
            Button(L10n.text("button.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("hint.use.message"))
        }
        .alert(
            L10n.text("hint.grant.title"),
            isPresented: $showHintGrantDialog
        ) {
            TextField(L10n.text("hint.grant.field"), text: $hintGrantText)
                .keyboardType(.numberPad)

            Button(L10n.text("button.add")) {
                grantHintPoints(Int(hintGrantText) ?? 0)
            }
            Button(L10n.text("button.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.format("hint.grant.message", hintPoints, Self.maximumHintPoints))
        }
        .alert(
            L10n.text("replace.confirm.title"),
            isPresented: $showReplacePuzzleConfirmDialog
        ) {
            Button(L10n.text("button.replace"), role: .destructive) {
                withAnimation(.snappy) {
                    replacePuzzle(for: currentPuzzleKey)
                }
            }
            Button(L10n.text("button.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("replace.confirm.message"))
        }
        .sheet(isPresented: $showHowToPlaySheet) {
            howToPlaySheet
        }
    }

    private var appBackground: some View {
        let theme = backgroundTheme

        return GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: theme.baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<theme.bandCount, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: theme.accentColors.map { $0.opacity(theme.bandOpacity) },
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 1.45, height: CGFloat(52 + index * 18))
                        .rotationEffect(.degrees(-12 + Double(index % 2) * 22))
                        .offset(
                            x: CGFloat(index - theme.bandCount / 2) * geometry.size.width * 0.10,
                            y: -geometry.size.height * 0.30 + CGFloat(index) * geometry.size.height * 0.22
                        )
                        .blendMode(.softLight)
                }

                Canvas { context, size in
                    let spacing = max(24, size.width / 22)
                    var x = -size.height
                    while x < size.width + size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        context.stroke(
                            path,
                            with: .color(theme.lineColor.opacity(theme.lineOpacity)),
                            lineWidth: 1
                        )
                        x += spacing
                    }
                }
                .blendMode(.softLight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            headerTitle
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

            Spacer(minLength: 10)

            HStack(spacing: 14) {
                levelBadge
                    .layoutPriority(1)

                headerActionControls
                    .layoutPriority(1)
            }
            .padding(.trailing, 24)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: panelRadius)
                .stroke(Color.white.opacity(0.64), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.12), radius: 24, y: 12)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L10n.text("app.title"))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("v\(appVersion)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.58))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .foregroundStyle(ink)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                resetAchievementLevelText = "\(currentLevelNumber)"
                showResetAchievementsDialog = true
            }
            Text(L10n.format("header.level.detail", currentLevelNumber, boardSize, boardSize, blockCount, difficulty.title))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
            Text(L10n.format("header.clear.count", currentSolvedCount))
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ink.opacity(0.68))
            Text(unlockMessage ?? " ")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(unlockMessage == nil ? Color.clear : errorAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 16, alignment: .leading)
        }
    }

    private var headerControls: some View {
        HStack(spacing: 14) {
            levelBadge
            headerActionControls
        }
    }

    private var levelBadge: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("LEVEL")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.54))
                Text("\(currentLevelNumber)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 6) {
                Text(difficulty.title)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                levelClearProgress
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: 96, height: 62)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var levelClearProgress: some View {
        HStack(spacing: 4) {
            ForEach(0..<currentClearRequirement, id: \.self) { index in
                Image(systemName: index < min(currentSolvedCount, currentClearRequirement) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(index < min(currentSolvedCount, currentClearRequirement) ? accent : ink.opacity(0.20))
                    .frame(width: 13, height: 13)
            }
        }
        .accessibilityLabel(L10n.format("header.clear.progress", currentSolvedCount, currentClearRequirement))
    }

    private var headerActionControls: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { column in
                            let index = row * 5 + column
                            Image(systemName: index < hintPoints ? "heart.fill" : "heart")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(index < hintPoints ? heartAccent : ink.opacity(0.18))
                                .frame(width: 11, height: 11)
                        }
                    }
                }
            }
            .frame(width: 78, height: 50)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: ink.opacity(0.12), radius: 6, y: 3)
            .opacity(hintPoints <= 0 ? 0.62 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                requestRandomHint()
            }
            .onLongPressGesture(minimumDuration: 0.55) {
                presentHintGrantDialog()
            }

            HStack(spacing: 8) {
                headerIconButton(
                    systemImage: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    background: Color.white.opacity(0.92),
                    accessibilityLabel: L10n.text(isSoundEnabled ? "button.sound.off" : "button.sound.on")
                ) {
                    toggleSound()
                }

                headerIconButton(
                    systemImage: "arrow.clockwise",
                    background: Color(red: 0.95, green: 0.72, blue: 0.24),
                    accessibilityLabel: L10n.text("button.redeal")
                ) {
                    showReplacePuzzleConfirmDialog = true
                }

                Button {
                    showHowToPlaySheet = true
                } label: {
                    Text("?")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(color: ink.opacity(0.12), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ink)
                .accessibilityLabel(L10n.text("howto.title"))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func headerIconButton(
        systemImage: String,
        background: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .heavy))
                .frame(width: 50, height: 50)
                .background(background)
                .clipShape(Circle())
                .shadow(color: ink.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityLabel(accessibilityLabel)
    }

    private var howToPlaySheet: some View {
        NavigationStack {
            GeometryReader { geometry in
                TabView {
                    howToPlayPage(
                        title: L10n.text("howto.rule.title"),
                        body: L10n.text("howto.rule.body"),
                        availableHeight: geometry.size.height
                    ) {
                        howToPlayEquationIllustration
                    }

                    howToPlayPage(
                        title: L10n.text("howto.clear.title"),
                        body: L10n.text("howto.clear.body"),
                        availableHeight: geometry.size.height
                    ) {
                        howToPlayClearIllustration
                    }

                    howToPlayPage(
                        title: L10n.text("howto.level.move.title"),
                        body: L10n.text("howto.level.move.body"),
                        availableHeight: geometry.size.height
                    ) {
                        howToPlayLevelMoveIllustration
                    }

                    howToPlayPage(
                        title: L10n.text("howto.replace.title"),
                        body: L10n.text("howto.replace.body"),
                        availableHeight: geometry.size.height
                    ) {
                        howToPlayReplaceIllustration
                    }

                    howToPlayPage(
                        title: L10n.text("howto.hint.title"),
                        body: L10n.text("howto.hint.body"),
                        availableHeight: geometry.size.height
                    ) {
                        howToPlayHintIllustration
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .background(panelBackground)
            .navigationTitle(L10n.text("howto.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("button.close")) {
                        showHowToPlaySheet = false
                    }
                }
            }
        }
    }

    private func howToPlayPage<Illustration: View>(
        title: String,
        body: String,
        availableHeight: CGFloat,
        @ViewBuilder illustration: () -> Illustration
    ) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                illustration()
                    .frame(maxWidth: .infinity)
                    .frame(height: min(300, max(180, availableHeight * 0.42)))

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                    Text(body)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.76))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 58)
        }
    }

    private var howToPlayEquationIllustration: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                howToPlayCell("3", highlighted: true)
                howToPlayCell("+", highlighted: false)
                howToPlayCell("4", highlighted: true)
                howToPlayCell("=", highlighted: false)
                howToPlayCell("7", highlighted: false)
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(accent)
                Text("3 + 4 = 7")
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var howToPlayClearIllustration: some View {
        HStack(spacing: 14) {
            howToPlayClearBadge(title: L10n.text("difficulty.beginner"), count: 1)
            howToPlayClearBadge(title: L10n.text("difficulty.intermediate"), count: 2)
            howToPlayClearBadge(title: L10n.text("difficulty.advanced"), count: 3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var howToPlayLevelMoveIllustration: some View {
        VStack(spacing: 16) {
            Text(L10n.text("app.title"))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedAccent, lineWidth: 3)
                )

            HStack(spacing: 18) {
                Image(systemName: "hand.tap.fill")
                Text("2x")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Image(systemName: "arrow.right")
                Text("LEVEL 60")
                    .font(.system(size: 21, weight: .heavy, design: .rounded).monospacedDigit())
            }
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(accent)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var howToPlayReplaceIllustration: some View {
        HStack(spacing: 22) {
            VStack(spacing: 8) {
                howToPlayMiniBoard(marked: false)
                Text("A")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.64))
            }

            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(selectedAccent)

            VStack(spacing: 8) {
                howToPlayMiniBoard(marked: true)
                Text("B")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.64))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var howToPlayHintIllustration: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index == 0 ? "heart.fill" : "heart")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(index == 0 ? heartAccent : ink.opacity(0.22))
                }
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(accent)

            HStack(spacing: 8) {
                howToPlayCell("?", highlighted: true)
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
                howToPlayCell("5", highlighted: false)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func howToPlayCell(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(highlighted ? accent : ink)
            .frame(width: 54, height: 54)
            .background(highlighted ? selectedAccent.opacity(0.28) : Color.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(ink.opacity(0.18), lineWidth: 1)
            )
    }

    private func howToPlayClearBadge(title: String, count: Int) -> some View {
        VStack(spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < count ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(index < count ? accent : ink.opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func howToPlayMiniBoard(marked: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 5)
                            .fill((marked && row == column) ? selectedAccent.opacity(0.48) : Color.white.opacity(0.86))
                            .frame(width: 27, height: 27)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(ink.opacity(0.16), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func unlockCelebration(message: String, encouragement: String?, nextKey: PuzzleCacheKey?) -> some View {
        let isGrandClear = message == Self.grandClearMessage

        return VStack(spacing: 14) {
            if isGrandClear {
                Image(L10n.imageName("GrandClearCelebration"))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
            } else {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(selectedAccent)

                Text(L10n.text("unlock.title"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)

                Text(message)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            if let encouragement, !isGrandClear {
                Text(encouragement)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .padding(.top, 2)
            }

            if let nextKey {
                Button {
                    goToUnlockedPuzzle(nextKey)
                } label: {
                    Label(isGrandClear ? L10n.text("button.to.level1") : L10n.text("button.next.level"), systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .frame(width: 240, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(selectedAccent)
                .foregroundStyle(ink)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(maxWidth: isGrandClear ? 560 : 420)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: panelRadius)
                .stroke(Color.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.24), radius: 30, y: 18)
    }

    private var nextPuzzlePrompt: some View {
        VStack(spacing: 16) {
            Text(L10n.text("clear.title"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)

            Text(L10n.format("clear.level.detail", currentLevelNumber, blockCount, difficulty.title))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(accent)

            if let clearProgressMessage {
                Text(clearProgressMessage)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(errorAccent)
                    .multilineTextAlignment(.center)
            }

            if let nextUnlockedPuzzleKey {
                Button {
                    goToUnlockedPuzzle(nextUnlockedPuzzleKey)
                } label: {
                    Label(L10n.text("button.next.level"), systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .frame(width: 240, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(selectedAccent)
                .foregroundStyle(ink)
            } else {
                Button {
                    goToNextPuzzle()
                } label: {
                    Label(L10n.text("button.next.game"), systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .frame(width: 220, height: 54)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(selectedAccent)
                .foregroundStyle(ink)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: panelRadius)
                .stroke(Color.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.24), radius: 30, y: 18)
    }

    private func blockCountButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .bold))
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.72, blue: 0.42),
                    panelTop,
                    panelBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            woodGrainOverlay(cornerRadius: panelRadius, opacity: 0.22)
        }
    }

    private func woodGrainOverlay(cornerRadius: CGFloat, opacity: Double) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)

            ZStack {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.18 : 0.10))
                        .frame(width: width * 0.92, height: max(0.7, width * 0.004))
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -9 : -5))
                        .offset(
                            x: CGFloat(index - 3) * width * 0.035,
                            y: CGFloat(index - 3) * height * 0.145
                        )
                }

                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(ink.opacity(0.10))
                        .frame(width: width * 0.78, height: max(0.6, width * 0.003))
                        .rotationEffect(.degrees(-7))
                        .offset(
                            x: CGFloat(2 - index) * width * 0.050,
                            y: CGFloat(index - 2) * height * 0.180
                        )
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private func cardTray(width: CGFloat, cardSide: CGFloat, spacing: CGFloat, padding: CGFloat) -> some View {
        let numberCards = puzzle.answerCards.indices.map { index in
            NumberCardItem(index: index, value: puzzle.answerCards[index])
        }
        let operatorCards = puzzle.operatorCards.indices.map { index in
            OperatorCardItem(index: index, operation: puzzle.operatorCards[index])
        }

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: cardSide, maximum: cardSide + 10), spacing: spacing)],
            spacing: spacing
        ) {
            ForEach(numberCards) { card in
                let isUsed = placedCards.values.contains { $0.cardIndex == card.index }
                let isSelected = selectedCardIndex == card.index

                Text("\(card.value)")
                    .font(.system(size: cardSide * 0.43, weight: .heavy, design: .rounded))
                    .foregroundStyle(isUsed ? ink.opacity(0.22) : (isSelected ? ink : accent))
                    .frame(width: cardSide, height: cardSide)
                    .background(
                        woodBlockBackground(isUsed: isUsed, isSelected: isSelected, cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? ink : ink.opacity(isUsed ? 0.18 : 0.58), lineWidth: isSelected ? 2.6 : 1.2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(
                        color: isSelected ? selectedAccent.opacity(0.38) : .clear,
                        radius: isSelected ? 16 : 0,
                        y: isSelected ? 8 : 0
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isUsed else { return }
                        selectedCardIndex = isSelected ? nil : card.index
                        selectedOperatorCardIndex = nil
                    }
            }

            ForEach(operatorCards) { card in
                let isUsed = placedOperatorCards.values.contains { $0.cardIndex == card.index }
                let isSelected = selectedOperatorCardIndex == card.index

                Text(card.operation.rawValue)
                    .font(.system(size: cardSide * 0.43, weight: .heavy, design: .rounded))
                    .foregroundStyle(isUsed ? ink.opacity(0.22) : (isSelected ? ink : accent))
                    .frame(width: cardSide, height: cardSide)
                    .background(
                        woodBlockBackground(isUsed: isUsed, isSelected: isSelected, cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? ink : ink.opacity(isUsed ? 0.18 : 0.58), lineWidth: isSelected ? 2.6 : 1.2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(
                        color: isSelected ? selectedAccent.opacity(0.38) : .clear,
                        radius: isSelected ? 16 : 0,
                        y: isSelected ? 8 : 0
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isUsed else { return }
                        selectedOperatorCardIndex = isSelected ? nil : card.index
                        selectedCardIndex = nil
                    }
            }
        }
        .frame(width: width)
        .padding(padding)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: panelRadius)
                .stroke(Color.white.opacity(0.64), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.12), radius: 24, y: 12)
    }

    private func board(side: CGFloat) -> some View {
        let offset = centeredContentOffset()
        let boardPadding: CGFloat = 6
        let cellSide = (side - boardPadding * 2 - CGFloat(boardSize - 1) * cellSpacing) / CGFloat(boardSize)

        return LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(0..<(boardSize * boardSize), id: \.self) { index in
                let sourceRow = index / boardSize - offset.row
                let sourceColumn = index % boardSize - offset.column
                cell(row: sourceRow, column: sourceColumn, cellSide: cellSide)
            }
        }
        .frame(width: side, height: side)
        .padding(boardPadding)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: panelRadius)
                .stroke(Color.white.opacity(0.66), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.15), radius: 30, y: 16)
    }

    private func cell(row: Int, column: Int, cellSide: CGFloat) -> some View {
        let point = GridPoint(row: row, column: column)
        let block = puzzle.solution.block(at: point)
        let isHiddenNumber = puzzle.hiddenNumberPoints.contains(point)
        let isHiddenOperator = puzzle.hiddenOperatorPoints.contains(point)
        let placedNumberValue = placedCards[point]?.value
        let placedOperatorValue = placedOperatorCards[point]?.operation
        let content = placedNumberValue.map(String.init) ?? placedOperatorValue?.rawValue ?? puzzle.visibleContents[point]
        let hintedContent = hintedNumberPoints.contains(point) ? puzzle.solution.cellContents[point] : nil
        let hasPlacedValue = placedNumberValue != nil || placedOperatorValue != nil
        let isFloatingPlacedValue = isFloatingPlacedInput(at: point)
        let isSnappingPlacedValue = snappingPlacedPoints.contains(point)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellFill(block: block, point: point, content: content, hasPlacedValue: hasPlacedValue))
                .overlay(
                    blockBevelOverlay(
                        cornerRadius: 4,
                        isActive: block != nil,
                        highlightOpacity: hasPlacedValue ? 0.42 : 0.34,
                        shadowOpacity: hasPlacedValue ? 0.22 : 0.17
                    )
                )
                .shadow(
                    color: cellShadow(
                        block: block,
                        point: point,
                        hasPlacedValue: hasPlacedValue,
                        isFloatingPlacedValue: isFloatingPlacedValue
                    ),
                    radius: isFloatingPlacedValue ? 14 : 4,
                    x: 0,
                    y: isFloatingPlacedValue ? 12 : 3
                )

            if block != nil {
                woodGrainOverlay(
                    cornerRadius: 4,
                    opacity: (isHiddenNumber || isHiddenOperator) && !hasPlacedValue ? 0.12 : 0.24
                )
            }

            if let content {
                Text(content)
                    .font(.system(size: max(17, min(32, cellSide * 0.62)), weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .foregroundStyle(hasPlacedValue ? accent : ink)
            } else if let hintedContent {
                Text(hintedContent)
                    .font(.system(size: max(17, min(32, cellSide * 0.62)), weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .foregroundStyle(ink.opacity(0.26))
            }
        }
        .scaleEffect(isFloatingPlacedValue ? 1.10 : (isSnappingPlacedValue ? 0.92 : 1.0))
        .offset(y: isFloatingPlacedValue ? -7.0 : (isSnappingPlacedValue ? 3.5 : 0))
        .zIndex(isFloatingPlacedValue ? 2 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    Color.white.opacity(block == nil ? 0 : (hasPlacedValue ? 0.12 : 0.34)),
                    lineWidth: 0.6
                )
                .padding(1)
        )
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.22, dampingFraction: 0.58), value: isFloatingPlacedValue)
        .animation(.easeOut(duration: 0.12), value: isSnappingPlacedValue)
        .onTapGesture {
            guard isHiddenNumber || isHiddenOperator else { return }
            placeSelectedCard(at: point)
        }
    }

    private func centeredContentOffset() -> (row: Int, column: Int) {
        let cells = puzzle.solution.occupiedCells
        guard
            let minRow = cells.map(\.row).min(),
            let maxRow = cells.map(\.row).max(),
            let minColumn = cells.map(\.column).min(),
            let maxColumn = cells.map(\.column).max()
        else {
            return (0, 0)
        }

        let contentHeight = maxRow - minRow + 1
        let contentWidth = maxColumn - minColumn + 1
        let targetMinRow = max((boardSize - contentHeight) / 2, 0)
        let targetMinColumn = max((boardSize - contentWidth) / 2, 0)

        return (targetMinRow - minRow, targetMinColumn - minColumn)
    }

    private func borderColor(block: BoardBlock?, point: GridPoint, hasEquationError: Bool) -> Color {
        guard block != nil else {
            return .clear
        }

        if hasEquationError {
            return errorAccent
        }

        if placedCards[point] != nil || placedOperatorCards[point] != nil {
            return .clear
        }

        if puzzle.hiddenNumberPoints.contains(point), placedCards[point] == nil {
            return ink.opacity(0.34)
        }

        if puzzle.hiddenOperatorPoints.contains(point), placedOperatorCards[point] == nil {
            return ink.opacity(0.34)
        }

        return ink
    }

    private func isIncorrectPlacedInput(at point: GridPoint) -> Bool {
        guard placedCards[point] != nil || placedOperatorCards[point] != nil else {
            return false
        }

        return puzzle.solution.blocks(at: point).contains { block in
            let points = numberPoints(for: block)
            guard points.contains(point) else {
                return false
            }

            guard
                let lhs = currentNumberValue(at: points[0]),
                let rhs = currentNumberValue(at: points[1]),
                let result = currentNumberValue(at: points[2]),
                let operation = currentOperatorValue(for: block)
            else {
                return false
            }

            return operation.apply(lhs, rhs) != result
        }
    }

    private func isFloatingPlacedInput(at point: GridPoint) -> Bool {
        guard placedCards[point] != nil || placedOperatorCards[point] != nil else {
            return false
        }

        let relatedBlocks = puzzle.solution.blocks(at: point)
        guard !relatedBlocks.isEmpty else {
            return false
        }

        return !relatedBlocks.allSatisfy { block in
            isCompleteAndCorrect(block)
        }
    }

    private func isCompleteAndCorrect(_ block: BoardBlock) -> Bool {
        let points = numberPoints(for: block)
        guard
            let lhs = currentNumberValue(at: points[0]),
            let rhs = currentNumberValue(at: points[1]),
            let result = currentNumberValue(at: points[2]),
            let operation = currentOperatorValue(for: block)
        else {
            return false
        }

        return operation.apply(lhs, rhs) == result
    }

    private func currentNumberValue(at point: GridPoint) -> Int? {
        if let placedValue = placedCards[point]?.value {
            return placedValue
        }

        return Int(puzzle.visibleContents[point] ?? "")
    }

    private func currentOperatorValue(for block: BoardBlock) -> ArithmeticOperator? {
        let point = block.cells[1]
        if let placedOperation = placedOperatorCards[point]?.operation {
            return placedOperation
        }

        return ArithmeticOperator(rawValue: puzzle.visibleContents[point] ?? "")
    }

    private func numberPoints(for block: BoardBlock) -> [GridPoint] {
        let cells = block.cells
        return [cells[0], cells[2], cells[4]]
    }

    private func cellShadow(
        block: BoardBlock?,
        point: GridPoint,
        hasPlacedValue: Bool,
        isFloatingPlacedValue: Bool = false
    ) -> Color {
        guard block != nil else {
            return .clear
        }

        if isFloatingPlacedValue {
            return ink.opacity(0.55)
        }

        if (puzzle.hiddenNumberPoints.contains(point) || puzzle.hiddenOperatorPoints.contains(point)), !hasPlacedValue {
            return ink.opacity(0.06)
        }

        return ink.opacity(hasPlacedValue ? 0.30 : 0.18)
    }

    private func cellFill(
        block: BoardBlock?,
        point: GridPoint,
        content: String?,
        hasPlacedValue: Bool
    ) -> AnyShapeStyle {
        guard block != nil else {
            return AnyShapeStyle(Color.clear)
        }

        if hasPlacedValue {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.84, blue: 0.72),
                        placedFill
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if puzzle.hiddenNumberPoints.contains(point) || puzzle.hiddenOperatorPoints.contains(point) {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.70, green: 0.49, blue: 0.29),
                        emptyFill
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if let content, Int(content) != nil {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.98, blue: 0.91),
                        givenFill
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.88),
                    operatorFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func woodBlockBackground(
        isUsed: Bool,
        isSelected: Bool = false,
        cornerRadius: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardFillStyle(isUsed: isUsed, isSelected: isSelected))
                .overlay(
                    blockBevelOverlay(
                        cornerRadius: cornerRadius,
                        isActive: !isUsed,
                        highlightOpacity: isSelected ? 0.52 : 0.44,
                        shadowOpacity: isSelected ? 0.28 : 0.22
                    )
                )

            if !isUsed {
                woodGrainOverlay(cornerRadius: cornerRadius, opacity: isSelected ? 0.34 : 0.26)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(isUsed ? 0 : 0.42), lineWidth: 1)
                .padding(1.3)
        )
        .shadow(color: Color.white.opacity(isUsed ? 0 : 0.42), radius: 1, x: -1, y: -1)
        .shadow(color: ink.opacity(isUsed ? 0 : 0.30), radius: 7, x: 0, y: 5)
    }

    private func blockBevelOverlay(
        cornerRadius: CGFloat,
        isActive: Bool,
        highlightOpacity: Double,
        shadowOpacity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isActive ? highlightOpacity : 0),
                        Color.white.opacity(isActive ? highlightOpacity * 0.30 : 0),
                        ink.opacity(isActive ? shadowOpacity : 0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(cornerRadius - 1, 1))
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? highlightOpacity * 0.30 : 0),
                                Color.clear,
                                ink.opacity(isActive ? shadowOpacity * 0.45 : 0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .padding(2)
            )
    }

    private func cardFillStyle(isUsed: Bool, isSelected: Bool = false) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.77, blue: 0.35),
                        Color(red: 0.73, green: 0.39, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if isUsed {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ink.opacity(0.06),
                        ink.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.84, blue: 0.72),
                    cardFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func isUnlocked(blockCount: Int, difficulty: PuzzleDifficulty) -> Bool {
        guard let key = puzzleKey(forLevel: levelNumber(blockCount: blockCount, difficulty: difficulty)) else { return false }
        return isUnlocked(key)
    }

    private func levelNumber(for key: PuzzleCacheKey) -> Int {
        key.level
    }

    private func levelNumber(blockCount: Int, difficulty: PuzzleDifficulty) -> Int {
        let difficultyCount = PuzzleDifficulty.allCases.count
        return (blockCount - BoardPuzzle.blockCountRange.lowerBound) * difficultyCount + difficulty.sortOrder + 1
    }

    private func puzzleKey(forLevel level: Int) -> PuzzleCacheKey? {
        Self.puzzleKey(forLevel: level)
    }

    private func previousPuzzleKey(for key: PuzzleCacheKey) -> PuzzleCacheKey? {
        Self.previousPuzzleKey(for: key)
    }

    private func nextPuzzleKey(after key: PuzzleCacheKey) -> PuzzleCacheKey? {
        Self.nextPuzzleKey(after: key)
    }

    private func showUnlockMessage(for blockCount: Int, difficulty: PuzzleDifficulty) {
        withAnimation(.snappy) {
            let key = puzzleKey(forLevel: levelNumber(blockCount: blockCount, difficulty: difficulty))
            unlockMessage = key.map(unlockRequirementText(for:)) ?? L10n.text("level.unavailable")
        }
    }

    private func unlockRequirementText(for key: PuzzleCacheKey) -> String {
        guard let previousKey = previousPuzzleKey(for: key) else {
            return L10n.format("level.locked", key.level)
        }

        let remaining = remainingClears(
            required: clearRequirement(for: previousKey),
            current: clearCount(for: previousKey)
        )
        return L10n.format("level.unlock.requirement", key.level, previousKey.level, remaining)
    }

    private func clearRequirement(for key: PuzzleCacheKey) -> Int {
        Self.clearRequirementValue(for: key)
    }

    private func remainingClears(required: Int, current: Int) -> Int {
        max(required - current, 0)
    }

    private func levelUpRemainingMessage() -> String? {
        let remaining = remainingClears(
            required: clearRequirement(for: currentPuzzleKey),
            current: clearCount(for: currentPuzzleKey)
        )

        guard remaining > 0 else {
            return nil
        }

        return L10n.format("level.remaining", remaining)
    }

    private func clearCount(blockCount: Int, difficulty: PuzzleDifficulty) -> Int {
        guard let key = puzzleKey(forLevel: levelNumber(blockCount: blockCount, difficulty: difficulty)) else { return 0 }
        return clearCount(for: key)
    }

    private func clearCount(for key: PuzzleCacheKey) -> Int {
        solvedCounts[solvedCountKey(level: key.level), default: 0]
    }

    private func unlockedKeys() -> Set<PuzzleCacheKey> {
        var keys: Set<PuzzleCacheKey> = []

        for level in Self.availableLevelNumbers {
            if let key = puzzleKey(forLevel: level), isUnlocked(key) {
                keys.insert(key)
            }
        }

        return keys
    }

    private func celebrationUnlockText(for keys: Set<PuzzleCacheKey>) -> String? {
        let sortedKeys = sortedUnlockKeys(keys)

        guard let firstKey = sortedKeys.first else {
            return nil
        }

        if sortedKeys.count == 1 {
            return L10n.format("level.name", levelNumber(for: firstKey))
        }

        return L10n.format("level.name.more", levelNumber(for: firstKey), sortedKeys.count - 1)
    }

    private func sortedUnlockKeys(_ keys: Set<PuzzleCacheKey>) -> [PuzzleCacheKey] {
        let sortedKeys = keys.sorted { first, second in
            levelNumber(for: first) < levelNumber(for: second)
        }
        return sortedKeys
    }

    private func isUnlocked(_ key: PuzzleCacheKey) -> Bool {
        guard key.level >= 1 else {
            return false
        }

        guard clearCount(for: key) == 0 else {
            return true
        }

        guard let previousKey = previousPuzzleKey(for: key) else {
            return true
        }

        return clearCount(for: previousKey) >= clearRequirement(for: previousKey)
    }

    private func goToNextPuzzle() {
        withAnimation(.snappy) {
            showNextPuzzleButton = false
            nextUnlockedPuzzleKey = nil
            clearProgressMessage = nil
            replacePuzzle(for: currentPuzzleKey)
        }
    }

    private func goToUnlockedPuzzle(_ key: PuzzleCacheKey) {
        withAnimation(.snappy) {
            level = key.level
            blockCount = key.blockCount
            difficulty = key.difficulty
            Self.saveCurrentPuzzleKey(key)
            showNextPuzzleButton = false
            nextUnlockedPuzzleKey = nil
            clearProgressMessage = nil
            celebrationUnlockMessage = nil
            celebrationEncouragementMessage = nil
            showConfetti = false
            unlockMessage = nil
            replacePuzzle(for: key)
        }
    }

    private func resetAchievements(through requestedLevel: Int) {
        let targetLevel = min(max(requestedLevel, 1), maximumLevelNumber)
        var seededSolvedCounts: [String: Int] = [:]

        if targetLevel > 1 {
            for level in Self.availableLevelNumbers where level < targetLevel {
                guard let key = puzzleKey(forLevel: level) else {
                    continue
                }

                seededSolvedCounts[solvedCountKey(level: level)] = clearRequirement(for: key)
            }
        }

        solvedCounts = [:]
        completedPuzzleIDs = [:]
        currentPreparedPuzzleID = nil
        placedCards = [:]
        placedOperatorCards = [:]
        selectedCardIndex = nil
        selectedOperatorCardIndex = nil
        hintedNumberPoints = []
        showConfetti = false
        celebrationUnlockMessage = nil
        celebrationEncouragementMessage = nil
        clearProgressMessage = nil
        nextUnlockedPuzzleKey = nil
        showNextPuzzleButton = false
        hasCelebratedCurrentPuzzle = false
        unlockMessage = nil
        solvedCounts = seededSolvedCounts
        Self.saveSolvedCounts(solvedCounts)
        Self.saveCompletedPuzzleIDs(completedPuzzleIDs)

        withAnimation(.snappy) {
            let key = puzzleKey(forLevel: targetLevel) ??
                PuzzleCacheKey(level: 1, blockCount: BoardPuzzle.defaultBlockCount, difficulty: .beginner)
            level = key.level
            blockCount = key.blockCount
            difficulty = key.difficulty
            Self.saveCurrentPuzzleKey(key)
            replacePuzzle(for: key)
        }
    }

    private func setLevel(_ newLevel: Int) {
        guard let key = puzzleKey(forLevel: newLevel) else {
            return
        }

        guard key.level != level else {
            return
        }

        guard isUnlocked(key) else {
            withAnimation(.snappy) {
                unlockMessage = unlockRequirementText(for: key)
            }
            return
        }

        withAnimation(.snappy) {
            level = key.level
            blockCount = key.blockCount
            difficulty = key.difficulty
            Self.saveCurrentPuzzleKey(key)
            unlockMessage = nil
            replacePuzzle(for: key)
        }
    }

    private func replacePuzzle(blockCount: Int, difficulty: PuzzleDifficulty) {
        guard let key = puzzleKey(forLevel: levelNumber(blockCount: blockCount, difficulty: difficulty)) else { return }
        replacePuzzle(for: key)
    }

    private func replacePuzzle(for key: PuzzleCacheKey) {
        guard isUnlocked(key) else {
            withAnimation(.snappy) {
                unlockMessage = unlockRequirementText(for: key)
            }
            return
        }

        guard let preparedPuzzle = bundledPreparedPuzzle(for: key) else {
            unlockMessage = L10n.text("level.no.pattern")
            return
        }

        applyPuzzle(preparedPuzzle.puzzle, puzzleID: preparedPuzzle.id, key: key)
    }

    private func bundledPreparedPuzzle(for key: PuzzleCacheKey) -> (id: Int, puzzle: PlayablePuzzle)? {
        let completionBucket = completedPuzzleBucket(for: key)
        let completedIDs = completedPuzzleIDs[completionBucket, default: []]
        if let preparedPuzzle = PreparedPuzzleCatalog.shared.puzzle(for: key, excluding: completedIDs) {
            return preparedPuzzle
        }

        guard !completedIDs.isEmpty else {
            return nil
        }

        completedPuzzleIDs[completionBucket] = []
        Self.saveCompletedPuzzleIDs(completedPuzzleIDs)
        return PreparedPuzzleCatalog.shared.puzzle(for: key, excluding: [])
    }

    private func completedPuzzleBucket(for key: PuzzleCacheKey) -> Int {
        Self.completedPuzzleBucket(for: key)
    }

    private func applyPuzzle(
        _ newPuzzle: PlayablePuzzle,
        puzzleID: Int?,
        key: PuzzleCacheKey
    ) {
        level = key.level
        blockCount = key.blockCount
        difficulty = key.difficulty
        puzzle = newPuzzle
        currentPreparedPuzzleID = puzzleID
        Self.saveCurrentPuzzleKey(key)
        placedCards = [:]
        placedOperatorCards = [:]
        selectedCardIndex = nil
        selectedOperatorCardIndex = nil
        hintedNumberPoints = []
        showConfetti = false
        celebrationUnlockMessage = nil
        celebrationEncouragementMessage = nil
        clearProgressMessage = nil
        nextUnlockedPuzzleKey = nil
        showNextPuzzleButton = false
        hasCelebratedCurrentPuzzle = false
    }

    private func revealRandomHint() {
        guard hintPoints > 0 else {
            return
        }

        let candidates = puzzle.hiddenNumberPoints.filter { point in
            placedCards[point] == nil && !hintedNumberPoints.contains(point)
        }

        guard let point = candidates.randomElement() else {
            return
        }

        selectedCardIndex = nil
        selectedOperatorCardIndex = nil
        hintedNumberPoints.insert(point)
        hintPoints -= 1
        Self.saveHintPoints(hintPoints)
    }

    private func requestRandomHint() {
        guard hintPoints > 0, hasAvailableHintTarget else {
            return
        }

        showHintConfirmDialog = true
    }

    private func presentHintGrantDialog() {
        guard hintPoints < Self.maximumHintPoints else {
            return
        }

        hintGrantText = "1"
        showHintGrantDialog = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
    }

    private func grantHintPoints(_ points: Int) {
        guard points > 0, hintPoints < Self.maximumHintPoints else {
            return
        }

        hintPoints = min(Self.maximumHintPoints, hintPoints + points)
        Self.saveHintPoints(hintPoints)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
    }

    private var hasAvailableHintTarget: Bool {
        puzzle.hiddenNumberPoints.contains { point in
            placedCards[point] == nil && !hintedNumberPoints.contains(point)
        }
    }

    private func placeSelectedCard(at point: GridPoint) {
        if puzzle.hiddenOperatorPoints.contains(point) {
            placeSelectedOperatorCard(at: point)
            return
        }

        guard puzzle.hiddenNumberPoints.contains(point) else {
            return
        }

        if let existing = placedCards[point] {
            placedCards[point] = nil

            if selectedCardIndex == nil {
                selectedCardIndex = existing.cardIndex
                selectedOperatorCardIndex = nil
                return
            }
        }

        guard let selectedCardIndex else {
            return
        }

        let floatingBefore = floatingPlacedInputPoints()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
            placedCards[point] = PlacedCard(
                cardIndex: selectedCardIndex,
                value: puzzle.answerCards[selectedCardIndex]
            )
            self.selectedCardIndex = nil
        }
        triggerSnapForSettledPoints(previouslyFloating: floatingBefore)
        playWoodBlockPlaceFeedback()
        checkCompletion()
    }

    private func placeSelectedOperatorCard(at point: GridPoint) {
        if let existing = placedOperatorCards[point] {
            placedOperatorCards[point] = nil

            if selectedOperatorCardIndex == nil {
                selectedOperatorCardIndex = existing.cardIndex
                selectedCardIndex = nil
                return
            }
        }

        guard let selectedOperatorCardIndex else {
            return
        }

        let floatingBefore = floatingPlacedInputPoints()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
            placedOperatorCards[point] = PlacedOperatorCard(
                cardIndex: selectedOperatorCardIndex,
                operation: puzzle.operatorCards[selectedOperatorCardIndex]
            )
            self.selectedOperatorCardIndex = nil
        }
        triggerSnapForSettledPoints(previouslyFloating: floatingBefore)
        checkCompletion()
    }

    private func floatingPlacedInputPoints() -> Set<GridPoint> {
        let points = Array(placedCards.keys) + Array(placedOperatorCards.keys)
        return Set(points.filter { isFloatingPlacedInput(at: $0) })
    }

    private func triggerSnapForSettledPoints(previouslyFloating: Set<GridPoint>) {
        let settledPoints = previouslyFloating.subtracting(floatingPlacedInputPoints())
        guard !settledPoints.isEmpty else {
            return
        }

        withAnimation(.easeOut(duration: 0.10)) {
            snappingPlacedPoints.formUnion(settledPoints)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.50)) {
                snappingPlacedPoints.subtract(settledPoints)
            }
        }
    }

    private func checkCompletion() {
        guard !hasCelebratedCurrentPuzzle else {
            return
        }

        let numbersSolved = puzzle.hiddenNumberPoints.allSatisfy { point in
            guard
                let placedValue = placedCards[point]?.value,
                let solutionValue = Int(puzzle.solution.cellContents[point] ?? "")
            else {
                return false
            }

            return placedValue == solutionValue
        }

        let operatorsSolved = puzzle.hiddenOperatorPoints.allSatisfy { point in
            guard
                let placedOperation = placedOperatorCards[point]?.operation,
                let solutionOperation = ArithmeticOperator(rawValue: puzzle.solution.cellContents[point] ?? "")
            else {
                return false
            }

            return placedOperation == solutionOperation
        }

        let isSolved = numbersSolved && operatorsSolved

        guard isSolved else {
            return
        }

        let willCompleteMaximumLevel = currentLevelNumber == maximumLevelNumber &&
            clearCount(for: currentPuzzleKey) + 1 >= clearRequirement(for: currentPuzzleKey)
        hasCelebratedCurrentPuzzle = true
        celebrationID += 1
        let unlockResult = recordSolvedPuzzle()
        if willCompleteMaximumLevel {
            resetProgressAfterCompletingMaximumLevel()
        }
        let unlockedAchievement = unlockResult != nil
        let progressMessage = (unlockResult == nil && !willCompleteMaximumLevel) ? levelUpRemainingMessage() : nil
        let encouragementMessage = unlockResult == nil ? nil : Self.encouragementMessages.randomElement()

        withAnimation(.easeOut(duration: 0.2)) {
            celebrationUnlockMessage = willCompleteMaximumLevel ? Self.grandClearMessage : unlockResult?.message
            celebrationEncouragementMessage = encouragementMessage
            clearProgressMessage = progressMessage
            nextUnlockedPuzzleKey = willCompleteMaximumLevel ? Self.firstPuzzleKey() : (unlockResult?.nextKey ?? nextUnlockedLevelKey())
            showConfetti = true
        }

        playVictoryFeedback(unlockedAchievement: unlockedAchievement, grandVictory: willCompleteMaximumLevel)

        let completedCelebrationID = celebrationID
        DispatchQueue.main.asyncAfter(deadline: .now() + (willCompleteMaximumLevel ? 6.4 : 2.4)) {
            guard celebrationID == completedCelebrationID else {
                return
            }

            withAnimation(.easeOut(duration: 0.35)) {
                showConfetti = false
                if unlockedAchievement {
                    showNextPuzzleButton = false
                } else {
                    celebrationUnlockMessage = nil
                    celebrationEncouragementMessage = nil
                    showNextPuzzleButton = true
                }
            }
        }
    }

    private func playWoodBlockPlaceFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
        playSystemSound(1104)
    }

    private func playVictoryFeedback(unlockedAchievement: Bool, grandVictory: Bool = false) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if grandVictory {
            playGrandVictorySound()
        } else {
            playSystemSound(unlockedAchievement ? 1025 : 1022)
        }
    }

    private func playGrandVictorySound() {
        let sounds: [SystemSoundID] = [1025, 1022, 1025, 1027, 1025]
        for (index, sound) in sounds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.32) {
                playSystemSound(sound)
            }
        }
    }

    private func playSystemSound(_ sound: SystemSoundID) {
        guard isSoundEnabled else {
            return
        }

        AudioServicesPlaySystemSound(sound)
    }

    private func toggleSound() {
        isSoundEnabled.toggle()
        Self.saveSoundEnabled(isSoundEnabled)
    }

    private func nextUnlockedLevelKey() -> PuzzleCacheKey? {
        guard
            let nextKey = nextPuzzleKey(after: currentPuzzleKey),
            isUnlocked(nextKey)
        else {
            return nil
        }

        return nextKey
    }

    private func resetProgressAfterCompletingMaximumLevel() {
        solvedCounts = [:]
        completedPuzzleIDs = [:]
        Self.saveSolvedCounts(solvedCounts)
        Self.saveCompletedPuzzleIDs(completedPuzzleIDs)
        if let firstKey = Self.firstPuzzleKey() {
            Self.saveCurrentPuzzleKey(firstKey)
        }
    }

    @discardableResult
    private func recordSolvedPuzzle() -> UnlockResult? {
        let beforeUnlockedKeys = unlockedKeys()
        let clearCountBefore = clearCount(for: currentPuzzleKey)
        let clearRequirement = clearRequirement(for: currentPuzzleKey)
        let willClearLevel = clearCountBefore < clearRequirement &&
            clearCountBefore + 1 >= clearRequirement
        let completionBucket = completedPuzzleBucket(for: currentPuzzleKey)
        if let currentPreparedPuzzleID {
            completedPuzzleIDs[completionBucket, default: []].insert(currentPreparedPuzzleID)
        }
        resetCompletedPuzzleIDsIfNeeded(for: currentPuzzleKey, completionBucket: completionBucket)
        Self.saveCompletedPuzzleIDs(completedPuzzleIDs)
        solvedCounts[solvedCountKey(level: currentLevelNumber), default: 0] += 1
        if willClearLevel {
            hintPoints = min(Self.maximumHintPoints, hintPoints + 1)
            Self.saveHintPoints(hintPoints)
        }
        unlockMessage = nil
        Self.saveSolvedCounts(solvedCounts)
        let afterUnlockedKeys = unlockedKeys()
        let newlyUnlockedKeys = afterUnlockedKeys.subtracting(beforeUnlockedKeys)
        guard
            let message = celebrationUnlockText(for: newlyUnlockedKeys),
            let nextKey = sortedUnlockKeys(newlyUnlockedKeys).first
        else {
            return nil
        }

        return UnlockResult(message: message, nextKey: nextKey)
    }

    private func resetCompletedPuzzleIDsIfNeeded(for key: PuzzleCacheKey, completionBucket: Int) {
        let availablePuzzleCount = PreparedPuzzleCatalog.shared.count(for: key)
        guard
            availablePuzzleCount > 0,
            completedPuzzleIDs[completionBucket, default: []].count >= availablePuzzleCount
        else {
            return
        }

        completedPuzzleIDs[completionBucket] = []
    }

    private func solvedCountKey(level: Int) -> String {
        Self.solvedCountKey(level: level)
    }

    private static func solvedCountKey(level: Int) -> String {
        "level-\(level)"
    }

    private static func loadSolvedCounts() -> [String: Int] {
        guard let storedCounts = UserDefaults.standard.dictionary(forKey: solvedCountsKey) else {
            return [:]
        }

        var counts: [String: Int] = [:]
        for (key, value) in storedCounts {
            if let count = value as? Int {
                counts[normalizedSolvedCountKey(key)] = count
            } else if let count = value as? NSNumber {
                counts[normalizedSolvedCountKey(key)] = count.intValue
            }
        }

        return counts
    }

    private static func loadHintPoints() -> Int {
        min(max(UserDefaults.standard.integer(forKey: hintPointsKey), 0), maximumHintPoints)
    }

    private static func saveHintPoints(_ points: Int) {
        UserDefaults.standard.set(min(max(points, 0), maximumHintPoints), forKey: hintPointsKey)
    }

    private static func loadSoundEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: soundEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    private static func saveSoundEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: soundEnabledKey)
    }

    private static func normalizedSolvedCountKey(_ key: String) -> String {
        if key.hasPrefix("level-") {
            return key
        }

        if Int(key) != nil {
            return "level-\(key)"
        }

        let parts = key.split(separator: "-")
        if
            parts.count == 2,
            let blockCount = Int(parts[0]),
            let difficulty = PuzzleDifficulty(rawValue: String(parts[1]))
        {
            return solvedCountKey(level: levelNumber(blockCount: blockCount, difficulty: difficulty))
        }

        return key
    }

    private static func loadCompletedPuzzleIDs() -> [Int: Set<Int>] {
        guard let stored = UserDefaults.standard.dictionary(forKey: completedPuzzleIDsKey) else {
            return [:]
        }

        var result: [Int: Set<Int>] = [:]
        for (key, value) in stored {
            guard let level = Int(key) else {
                continue
            }

            if let ids = value as? [Int] {
                result[level] = Set(ids)
            } else if let ids = value as? [NSNumber] {
                result[level] = Set(ids.map(\.intValue))
            }
        }
        return result
    }

    private static func initialPlayablePuzzle(
        for key: PuzzleCacheKey,
        completedPuzzleIDs: inout [Int: Set<Int>]
    ) -> (puzzle: PlayablePuzzle, puzzleID: Int?) {
        let completionBucket = completedPuzzleBucket(for: key)
        let completedIDs = completedPuzzleIDs[completionBucket, default: []]
        if let preparedPuzzle = PreparedPuzzleCatalog.shared.puzzle(for: key, excluding: completedIDs) {
            return (preparedPuzzle.puzzle, preparedPuzzle.id)
        }

        if !completedIDs.isEmpty, let preparedPuzzle = PreparedPuzzleCatalog.shared.puzzle(for: key, excluding: []) {
            completedPuzzleIDs[completionBucket] = []
            saveCompletedPuzzleIDs(completedPuzzleIDs)
            return (preparedPuzzle.puzzle, preparedPuzzle.id)
        }

        return (emptyPlayablePuzzle(for: key), nil)
    }

    private static func emptyPlayablePuzzle(for key: PuzzleCacheKey) -> PlayablePuzzle {
        let solution = BoardPuzzle(
            size: emptyBoardSize(for: key),
            blocks: [],
            connections: [],
            cellContents: [:],
            equations: [:]
        )

        return PlayablePuzzle(
            solution: solution,
            visibleContents: [:],
            answerCards: [],
            operatorCards: [],
            hiddenNumberPoints: [],
            hiddenOperatorPoints: [],
            givenNumberValues: [:],
            givenOperatorValues: [:]
        )
    }

    private static func emptyBoardSize(for key: PuzzleCacheKey) -> Int {
        if key.level >= 161 {
            return 18
        }

        return BoardPuzzle.size(for: key.blockCount)
    }

    private static func loadCurrentPuzzleKey(solvedCounts: [String: Int]) -> PuzzleCacheKey {
        let fallback = firstPuzzleKey() ??
            PuzzleCacheKey(level: 1, blockCount: BoardPuzzle.defaultBlockCount, difficulty: .beginner)
        return highestUnlockedPuzzleKey(solvedCounts: solvedCounts) ?? fallback
    }

    private static func saveCurrentPuzzleKey(_ key: PuzzleCacheKey) {
        UserDefaults.standard.set(key.level, forKey: currentLevelKey)
    }

    private static func highestUnlockedPuzzleKey(solvedCounts: [String: Int]) -> PuzzleCacheKey? {
        var highestKey: PuzzleCacheKey?
        var highestLevel = 0

        for level in availableLevelNumbers {
            guard
                let key = puzzleKey(forLevel: level),
                isUnlocked(key, solvedCounts: solvedCounts)
            else {
                continue
            }

            if level > highestLevel {
                highestLevel = level
                highestKey = key
            }
        }

        return highestKey
    }

    private static func puzzleKey(forLevel level: Int) -> PuzzleCacheKey? {
        preparedPuzzleKeysByLevel[level]
    }

    private static func firstPuzzleKey() -> PuzzleCacheKey? {
        availableLevelNumbers.first.flatMap { puzzleKey(forLevel: $0) }
    }

    private static func previousPuzzleKey(for key: PuzzleCacheKey) -> PuzzleCacheKey? {
        guard let index = availableLevelNumbers.firstIndex(of: key.level), index > 0 else {
            return nil
        }

        return puzzleKey(forLevel: availableLevelNumbers[index - 1])
    }

    private static func nextPuzzleKey(after key: PuzzleCacheKey) -> PuzzleCacheKey? {
        guard let index = availableLevelNumbers.firstIndex(of: key.level) else {
            return nil
        }

        let nextIndex = availableLevelNumbers.index(after: index)
        guard nextIndex < availableLevelNumbers.endIndex else {
            return nil
        }

        return puzzleKey(forLevel: availableLevelNumbers[nextIndex])
    }

    private static func levelNumber(blockCount: Int, difficulty: PuzzleDifficulty) -> Int {
        let difficultyCount = PuzzleDifficulty.allCases.count
        return (blockCount - BoardPuzzle.blockCountRange.lowerBound) * difficultyCount + difficulty.sortOrder + 1
    }

    private static func isUnlocked(
        _ key: PuzzleCacheKey,
        solvedCounts: [String: Int]
    ) -> Bool {
        guard availableLevelNumbers.contains(key.level) else {
            return false
        }

        guard solvedCounts[solvedCountKey(level: key.level), default: 0] == 0 else {
            return true
        }

        guard let previousKey = previousPuzzleKey(for: key) else {
            return true
        }

        return solvedCounts[solvedCountKey(level: previousKey.level), default: 0] >= clearRequirementValue(for: previousKey)
    }

    private static func completedPuzzleBucket(for key: PuzzleCacheKey) -> Int {
        key.level
    }

    private static func clearRequirementValue(for key: PuzzleCacheKey) -> Int {
        switch key.difficulty {
        case .beginner:
            return 1
        case .intermediate:
            return 2
        case .advanced, .expert:
            return 3
        }
    }

    private static func saveSolvedCounts(_ counts: [String: Int]) {
        UserDefaults.standard.set(counts, forKey: solvedCountsKey)
    }

    private static func saveCompletedPuzzleIDs(_ ids: [Int: Set<Int>]) {
        let encoded = Dictionary(
            uniqueKeysWithValues: ids.map { level, values in
                (String(level), values.sorted())
            }
        )
        UserDefaults.standard.set(encoded, forKey: completedPuzzleIDsKey)
    }
}

struct PuzzleCacheKey: Hashable, Codable {
    let level: Int
    let blockCount: Int
    let difficulty: PuzzleDifficulty
    var sourceLevel: Int

    init(level: Int, blockCount: Int, difficulty: PuzzleDifficulty, sourceLevel: Int? = nil) {
        self.level = level
        self.blockCount = blockCount
        self.difficulty = difficulty
        self.sourceLevel = sourceLevel ?? level
    }
}

private struct UnlockResult {
    let message: String
    let nextKey: PuzzleCacheKey
}

private struct BackgroundTheme {
    let baseColors: [Color]
    let accentColors: [Color]
    let lineColor: Color
    let bandOpacity: Double
    let lineOpacity: Double
    let bandCount: Int
}

private struct PlacedCard {
    let cardIndex: Int
    let value: Int
}

private struct PlacedOperatorCard {
    let cardIndex: Int
    let operation: ArithmeticOperator
}

private struct NumberCardItem: Identifiable {
    let index: Int
    let value: Int

    var id: String {
        "number-\(index)"
    }
}

private struct OperatorCardItem: Identifiable {
    let index: Int
    let operation: ArithmeticOperator

    var id: String {
        "operator-\(index)"
    }
}

private struct ConfettiBurst: View {
    let trigger: Int

    @State private var isFalling = false

    private let colors: [Color] = [
        Color(red: 0.95, green: 0.72, blue: 0.24),
        Color(red: 0.04, green: 0.45, blue: 0.39),
        Color(red: 0.80, green: 0.94, blue: 0.88),
        Color(red: 0.99, green: 0.99, blue: 0.96)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<72, id: \.self) { index in
                    let profile = ConfettiProfile(index: index, size: geometry.size)

                    RoundedRectangle(cornerRadius: profile.cornerRadius)
                        .fill(colors[index % colors.count])
                        .frame(width: profile.width, height: profile.height)
                        .rotationEffect(.degrees(isFalling ? profile.endRotation : profile.startRotation))
                        .offset(
                            x: profile.startX + (isFalling ? profile.driftX : 0),
                            y: isFalling ? profile.endY : profile.startY
                        )
                        .opacity(isFalling ? 0 : 0.98)
                        .animation(
                            .easeOut(duration: profile.duration)
                                .delay(profile.delay),
                            value: isFalling
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                isFalling = false
                DispatchQueue.main.async {
                    isFalling = true
                }
            }
            .id(trigger)
        }
        .ignoresSafeArea()
    }
}

private struct ConfettiProfile {
    let startX: CGFloat
    let driftX: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let startRotation: Double
    let endRotation: Double
    let duration: Double
    let delay: Double

    init(index: Int, size: CGSize) {
        let widthFraction = Self.fraction(index * 37 + 11)
        let driftFraction = Self.fraction(index * 53 + 19)
        let speedFraction = Self.fraction(index * 29 + 7)
        let shapeFraction = Self.fraction(index * 41 + 5)

        startX = (widthFraction - 0.5) * size.width
        driftX = (driftFraction - 0.5) * min(size.width * 0.55, 340)
        startY = -size.height * 0.46 - CGFloat(index % 9) * 10
        endY = size.height * 0.68 + CGFloat(index % 6) * 22
        width = 7 + CGFloat(shapeFraction) * 7
        height = 10 + CGFloat(Self.fraction(index * 17 + 23)) * 12
        cornerRadius = min(width, height) * 0.22
        startRotation = Double(index * 23 % 180)
        endRotation = startRotation + Double(220 + (index * 31 % 260))
        duration = 1.45 + Double(speedFraction) * 0.85
        delay = Double(index % 14) * 0.025
    }

    private static func fraction(_ value: Int) -> CGFloat {
        CGFloat((value * 73) % 997) / 997
    }
}

#Preview {
    ContentView()
}

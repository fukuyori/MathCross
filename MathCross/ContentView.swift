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
    @State private var showHintGrantDialog = false
    @State private var showHintConfirmDialog = false
    @State private var showReplacePuzzleConfirmDialog = false
    @State private var hintGrantText = ""
    @State private var pendingHintTapWorkItem: DispatchWorkItem?

    private let appVersion = "0.5.0"
    private let cellSpacing: CGFloat = 2
    private let ink = Color(red: 0.12, green: 0.15, blue: 0.18)
    private let accent = Color(red: 0.04, green: 0.45, blue: 0.39)
    private let selectedAccent = Color(red: 0.95, green: 0.72, blue: 0.24)
    private let errorAccent = Color(red: 0.86, green: 0.13, blue: 0.16)
    private let backgroundTop = Color(red: 0.78, green: 0.84, blue: 0.82)
    private let backgroundBottom = Color(red: 0.58, green: 0.68, blue: 0.65)
    private let panelTop = Color(red: 0.99, green: 0.99, blue: 0.96)
    private let panelBottom = Color(red: 0.91, green: 0.95, blue: 0.92)
    private let operatorFill = Color(red: 0.95, green: 0.91, blue: 0.75)
    private let givenFill = Color(red: 0.97, green: 0.93, blue: 0.76)
    private let emptyFill = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let placedFill = Color(red: 0.80, green: 0.94, blue: 0.88)
    private let cardFill = Color(red: 0.85, green: 0.96, blue: 0.93)
    private let panelRadius: CGFloat = 10
    private static let solvedCountsKey = "mathCross.solvedCountsByBlockCount"
    private static let currentLevelKey = "mathCross.currentLevel"
    private static let completedPuzzleIDsKey = "mathCross.completedPuzzleIDsByLevel"
    private static let hintPointsKey = "mathCross.hintPoints"
    private static let lastLevelNumber = 136
    private static let encouragementMessages = [
        "お疲れ様でございます",
        "大変お疲れ様でした",
        "ご苦労が偲ばれます",
        "お骨折りいただきありがとうございます",
        "ご尽力いただき感謝申し上げます",
        "お力添えありがとうございました",
        "お手数をおかけいたしました",
        "ご面倒をおかけしました",
        "ご助力を賜り、誠にありがとうございます",
        "ひとかたならぬお世話になりました",
        "ご功績に深く敬意を表します",
        "ご活躍、心よりお慶び申し上げます",
        "たゆまぬご努力に頭が下がる思いです",
        "ご精励の賜物と存じます",
        "ご研鑽の成果、感服いたしました",
        "ご奮闘ぶり、頼もしく拝見しております",
        "お見事なお働きでございました",
        "並々ならぬご努力に敬服いたします",
        "素晴らしいお仕事ぶりに感じ入っております",
        "ご精勤の様子、誠に頭が下がります",
        "ご多用の折、恐れ入ります",
        "ご多忙の中、誠にありがとうございました",
        "お忙しいところお手を煩わせました",
        "何かとご多端の折、お気遣い痛み入ります",
        "ご繁忙のところ恐縮に存じます",
        "お取り込み中失礼いたしました",
        "お忙しい中、お時間を割いていただき感謝いたします",
        "ご公務ご多忙の折、痛み入ります",
        "ご足労いただきありがとうございました",
        "遠路はるばるお越しいただき恐縮です",
        "長旅、さぞお疲れのことと存じます",
        "お運びいただき誠に恐れ入ります",
        "わざわざお越しいただき恐縮の至りです",
        "道中お疲れではございませんでしたか",
        "お疲れが出ませんよう、ご自愛ください",
        "お身体おいといくださいませ",
        "くれぐれもご無理なさいませんように",
        "ご心労いかばかりかとお察し申し上げます",
        "お疲れを癒されますように",
        "ご健康を切にお祈り申し上げます",
        "お休みになれましたでしょうか",
        "ご静養くださいませ",
        "お心遣い痛み入ります",
        "過分なお気遣いを賜り恐縮です",
        "ひとかたならぬご厚情に感謝いたします",
        "ご懇情、終生忘れません",
        "ご厚意のほど、深く御礼申し上げます",
        "お引き立てを賜り、誠にありがとうございます",
        "ご配慮いただき恐縮至極でございます",
        "ご高配を賜り、厚く御礼申し上げます",
        "さぞお骨折りのことでございましたでしょう",
        "ひとかたならぬご苦労をおかけしました",
        "ご苦心のほど、お察しいたします",
        "ご心痛いかばかりかとお見舞い申し上げます",
        "並々ならぬご労苦、頭が下がります",
        "大変な中、よくぞやり遂げてくださいました",
        "ご芳情のほど、肝に銘じます",
        "ご鞭撻に深謝申し上げます",
        "ひとえに皆様のおかげと存じます",
        "ご薫陶の賜物でございます",
        "ご恩情、深く心に刻んでおります",
        "お導きいただき、誠にありがとうございました",
        "お力添えのほど、終生忘れません",
        "皆様のご支援の賜物と、心より御礼申し上げます"
    ]

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
    }

    private var boardSize: Int {
        puzzle.solution.size
    }

    private var currentSolvedCount: Int {
        clearCount(for: currentPuzzleKey)
    }

    private var currentLevelNumber: Int {
        level
    }

    private var currentPuzzleKey: PuzzleCacheKey {
        puzzleKey(forLevel: level) ?? PuzzleCacheKey(level: level, blockCount: blockCount, difficulty: difficulty)
    }

    private var nextLevelKey: PuzzleCacheKey? {
        return puzzleKey(forLevel: currentLevelNumber + 1)
    }

    private var maximumLevelNumber: Int {
        Self.lastLevelNumber
    }

    private var levelProgress: Double {
        min(Double(level - 1) / Double(max(Self.lastLevelNumber - 1, 1)), 1)
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
                    1.08
                )
                let horizontalPadding = max(8, min(18, geometry.size.width * 0.014))
                let verticalPadding = max(8, min(16, geometry.size.height * 0.010))
                let contentSpacing = max(8, min(14, 10 * layoutScale))
                let cardSpacing = max(8, min(12, 10 * layoutScale))
                let trayPadding = max(8, min(12, 10 * layoutScale))
                let maximumContentWidth = geometry.size.width - horizontalPadding * 2
                let contentWidth = min(maximumContentWidth, 790 * layoutScale)
                let headerReservedHeight = max(92, 98 * layoutScale)
                let estimatedCardSide = max(50, min(72, contentWidth / 10.4))
                let cardsPerRow = max(Int((contentWidth - trayPadding * 2 + cardSpacing) / (estimatedCardSide + cardSpacing)), 1)
                let cardSide = max(
                    48,
                    min(
                        72,
                        (contentWidth - trayPadding * 2 - CGFloat(cardsPerRow - 1) * cardSpacing) / CGFloat(cardsPerRow)
                    )
                )
                let totalCardCount = puzzle.answerCards.count + puzzle.operatorCards.count
                let cardRows = CGFloat((totalCardCount + cardsPerRow - 1) / cardsPerRow)
                let trayHeight = cardRows * cardSide + max(cardRows - 1, 0) * cardSpacing + trayPadding * 2
                let reservedHeight = headerReservedHeight + trayHeight + contentSpacing * 2 + verticalPadding * 2
                let availableBoardSide = geometry.size.height - reservedHeight
                let side = max(
                    min(360 * layoutScale, contentWidth),
                    min(contentWidth, availableBoardSide)
                )

                VStack(spacing: contentSpacing) {
                    header

                    board(side: side)

                    cardTray(width: side + 12, cardSide: cardSide, spacing: cardSpacing, padding: trayPadding)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
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
            "実績を調整しますか",
            isPresented: $showResetAchievementsDialog,
        ) {
            TextField("残すレベル", text: $resetAchievementLevelText)
                .keyboardType(.numberPad)

            Button("実行", role: .destructive) {
                resetAchievements(through: Int(resetAchievementLevelText) ?? 0)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("0または1なら全実績を消去します。60ならレベル60までをクリア済みにして、レベル60から始めます。")
        }
        .alert(
            "ヒントを付与",
            isPresented: $showHintGrantDialog
        ) {
            TextField("追加するヒント数", text: $hintGrantText)
                .keyboardType(.numberPad)

            Button("付与") {
                grantHintPoints()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力した数だけヒントポイントを追加します。")
        }
        .alert(
            "ヒントを使いますか",
            isPresented: $showHintConfirmDialog
        ) {
            Button("使う") {
                revealRandomHint()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ヒントポイントを1つ消費して、未入力の数字を1つ表示します。")
        }
        .alert(
            "別のパターンに入れ替えますか",
            isPresented: $showReplacePuzzleConfirmDialog
        ) {
            Button("入れ替える", role: .destructive) {
                withAnimation(.snappy) {
                    replacePuzzle(for: currentPuzzleKey)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の入力内容は消えます。")
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                headerTitle

                Spacer()

                headerControls
            }

            VStack(alignment: .leading, spacing: 14) {
                headerTitle
                headerControls
            }
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
                Text("MathCross")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
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
            Text("レベル \(currentLevelNumber) / \(boardSize)x\(boardSize) / \(blockCount)個 / \(difficulty.title)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
            Text("正解数 \(currentSolvedCount)")
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
            VStack(spacing: 1) {
                Text("LEVEL")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.54))
                Text("\(currentLevelNumber)")
                    .font(.system(size: 27, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(blockCount)個 \(difficulty.title)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 112, height: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .heavy))
                Text("\(hintPoints)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 62, height: 50)
            .background(Color.white.opacity(0.94))
            .foregroundStyle(accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: ink.opacity(0.12), radius: 6, y: 3)
            .opacity(hintPoints <= 0 ? 0.62 : 1)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                handleHintDoubleTap()
            }
            .onTapGesture {
                handleHintSingleTap()
            }

            Button {
                showReplacePuzzleConfirmDialog = true
            } label: {
                Label("再配置", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(red: 0.95, green: 0.72, blue: 0.24))
            .foregroundStyle(ink)
            .frame(width: 50, height: 50)
        }
    }

    private func unlockCelebration(message: String, encouragement: String?, nextKey: PuzzleCacheKey?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(selectedAccent)

            Text("アンロック")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)

            Text(message)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if let encouragement {
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
                    Label("次のレベルへ", systemImage: "arrow.right.circle.fill")
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
        .frame(maxWidth: 420)
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
            Text("クリア")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)

            Text("レベル \(currentLevelNumber) / \(blockCount)個 / \(difficulty.title)")
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
                    Label("次のレベルへ", systemImage: "arrow.right.circle.fill")
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
                    Label("次のゲームへ", systemImage: "arrow.right.circle.fill")
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
        LinearGradient(
            colors: [
                panelTop,
                panelBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(cardFillStyle(isUsed: isUsed, isSelected: isSelected))
                            .shadow(color: Color.white.opacity(isUsed ? 0 : 0.55), radius: 1, x: -1, y: -1)
                            .shadow(color: ink.opacity(isUsed ? 0 : 0.16), radius: 4, x: 0, y: 3)
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(cardFillStyle(isUsed: isUsed, isSelected: isSelected))
                            .shadow(color: Color.white.opacity(isUsed ? 0 : 0.55), radius: 1, x: -1, y: -1)
                            .shadow(color: ink.opacity(isUsed ? 0 : 0.16), radius: 4, x: 0, y: 3)
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
        let hasEquationError = isIncorrectPlacedInput(at: point)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellFill(block: block, point: point, content: content, hasPlacedValue: hasPlacedValue))
                .shadow(color: cellShadow(block: block, point: point, hasPlacedValue: hasPlacedValue), radius: 3, x: 0, y: 2)

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
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    borderColor(block: block, point: point, hasEquationError: hasEquationError),
                    lineWidth: hasEquationError ? 2.6 : ((isHiddenNumber || isHiddenOperator) ? 1.2 : 1.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(block == nil ? 0 : 0.56), lineWidth: 0.8)
                .padding(1)
        )
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
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

    private func cellShadow(block: BoardBlock?, point: GridPoint, hasPlacedValue: Bool) -> Color {
        guard block != nil else {
            return .clear
        }

        if (puzzle.hiddenNumberPoints.contains(point) || puzzle.hiddenOperatorPoints.contains(point)), !hasPlacedValue {
            return ink.opacity(0.06)
        }

        return ink.opacity(0.18)
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
                        Color(red: 0.91, green: 1.00, blue: 0.94),
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
                        Color(red: 1.00, green: 0.99, blue: 0.95),
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
                        Color(red: 1.00, green: 0.98, blue: 0.84),
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
                    Color(red: 1.00, green: 0.97, blue: 0.82),
                    operatorFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func cardFillStyle(isUsed: Bool, isSelected: Bool = false) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.88, blue: 0.35),
                        Color(red: 0.96, green: 0.62, blue: 0.18)
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
                    Color(red: 0.91, green: 1.00, blue: 0.98),
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

    private func showUnlockMessage(for blockCount: Int, difficulty: PuzzleDifficulty) {
        withAnimation(.snappy) {
            let key = puzzleKey(forLevel: levelNumber(blockCount: blockCount, difficulty: difficulty))
            unlockMessage = key.map(unlockRequirementText(for:)) ?? "このレベルは選択できません"
        }
    }

    private func unlockRequirementText(for key: PuzzleCacheKey) -> String {
        guard key.level > 1, let previousKey = puzzleKey(forLevel: key.level - 1) else {
            return "レベル \(key.level) はまだ解放されていません"
        }

        let remaining = remainingClears(
            required: clearRequirement(for: previousKey),
            current: clearCount(for: previousKey)
        )
        return "レベル \(key.level) はレベル \(previousKey.level) をあと\(remaining)回クリアで解放"
    }

    private func clearRequirement(for key: PuzzleCacheKey) -> Int {
        if key.level >= 101 {
            return 3
        }

        if key.level >= 65 {
            return 3
        }

        switch key.difficulty {
        case .beginner:
            return 1
        case .intermediate:
            return 2
        case .advanced, .expert:
            return 3
        }
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

        return "レベルアップまで残り\(remaining)回だよ"
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

        for level in 1...maximumLevelNumber {
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
            return "レベル \(levelNumber(for: firstKey))"
        }

        return "レベル \(levelNumber(for: firstKey)) ほか\(sortedKeys.count - 1)件"
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

        guard key.level > 1, let previousKey = puzzleKey(forLevel: key.level - 1) else {
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
            for level in 1...targetLevel {
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
            unlockMessage = "このレベルのパターンデータがありません"
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

    private var hasAvailableHintTarget: Bool {
        puzzle.hiddenNumberPoints.contains { point in
            placedCards[point] == nil && !hintedNumberPoints.contains(point)
        }
    }

    private func handleHintSingleTap() {
        pendingHintTapWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            requestRandomHint()
            pendingHintTapWorkItem = nil
        }
        pendingHintTapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: workItem)
    }

    private func handleHintDoubleTap() {
        pendingHintTapWorkItem?.cancel()
        pendingHintTapWorkItem = nil
        openHintGrantDialog()
    }

    private func openHintGrantDialog() {
        hintGrantText = ""
        showHintGrantDialog = true
    }

    private func grantHintPoints() {
        guard let addedPoints = Int(hintGrantText), addedPoints > 0 else {
            hintGrantText = ""
            return
        }

        hintPoints += addedPoints
        Self.saveHintPoints(hintPoints)
        hintGrantText = ""
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

        placedCards[point] = PlacedCard(
            cardIndex: selectedCardIndex,
            value: puzzle.answerCards[selectedCardIndex]
        )
        self.selectedCardIndex = nil
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

        placedOperatorCards[point] = PlacedOperatorCard(
            cardIndex: selectedOperatorCardIndex,
            operation: puzzle.operatorCards[selectedOperatorCardIndex]
        )
        self.selectedOperatorCardIndex = nil
        checkCompletion()
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

        let willCompleteLevel100 = currentLevelNumber == 100 &&
            clearCount(for: currentPuzzleKey) + 1 >= clearRequirement(for: currentPuzzleKey)
        hasCelebratedCurrentPuzzle = true
        celebrationID += 1
        let unlockResult = recordSolvedPuzzle()
        let unlockedAchievement = unlockResult != nil
        let progressMessage = unlockResult == nil ? levelUpRemainingMessage() : nil
        let encouragementMessage = unlockResult == nil ? nil : Self.encouragementMessages.randomElement()

        withAnimation(.easeOut(duration: 0.2)) {
            celebrationUnlockMessage = willCompleteLevel100 ? "ゲームクリア" : unlockResult?.message
            celebrationEncouragementMessage = encouragementMessage
            clearProgressMessage = progressMessage
            nextUnlockedPuzzleKey = unlockResult?.nextKey ?? nextUnlockedLevelKey()
            showConfetti = true
        }

        playVictoryFeedback(unlockedAchievement: unlockedAchievement, grandVictory: willCompleteLevel100)

        let completedCelebrationID = celebrationID
        DispatchQueue.main.asyncAfter(deadline: .now() + (willCompleteLevel100 ? 6.4 : 2.4)) {
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

    private func playVictoryFeedback(unlockedAchievement: Bool, grandVictory: Bool = false) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if grandVictory {
            playGrandVictorySound()
        } else {
            AudioServicesPlaySystemSound(unlockedAchievement ? 1025 : 1022)
        }
    }

    private func playGrandVictorySound() {
        let sounds: [SystemSoundID] = [1025, 1022, 1025, 1027, 1025]
        for (index, sound) in sounds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.32) {
                AudioServicesPlaySystemSound(sound)
            }
        }
    }

    private func nextUnlockedLevelKey() -> PuzzleCacheKey? {
        guard
            let nextKey = puzzleKey(forLevel: currentLevelNumber + 1),
            isUnlocked(nextKey)
        else {
            return nil
        }

        return nextKey
    }

    @discardableResult
    private func recordSolvedPuzzle() -> UnlockResult? {
        let beforeUnlockedKeys = unlockedKeys()
        let completionBucket = completedPuzzleBucket(for: currentPuzzleKey)
        if let currentPreparedPuzzleID {
            completedPuzzleIDs[completionBucket, default: []].insert(currentPreparedPuzzleID)
        }
        resetCompletedPuzzleIDsIfNeeded(for: currentPuzzleKey, completionBucket: completionBucket)
        Self.saveCompletedPuzzleIDs(completedPuzzleIDs)
        solvedCounts[solvedCountKey(level: currentLevelNumber), default: 0] += 1
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
        max(UserDefaults.standard.integer(forKey: hintPointsKey), 0)
    }

    private static func saveHintPoints(_ points: Int) {
        UserDefaults.standard.set(max(points, 0), forKey: hintPointsKey)
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
            size: BoardPuzzle.size(for: key.blockCount),
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

    private static func loadCurrentPuzzleKey(solvedCounts: [String: Int]) -> PuzzleCacheKey {
        let fallback = PuzzleCacheKey(level: 1, blockCount: BoardPuzzle.defaultBlockCount, difficulty: .beginner)
        return highestUnlockedPuzzleKey(solvedCounts: solvedCounts) ?? fallback
    }

    private static func saveCurrentPuzzleKey(_ key: PuzzleCacheKey) {
        UserDefaults.standard.set(key.level, forKey: currentLevelKey)
    }

    private static func highestUnlockedPuzzleKey(solvedCounts: [String: Int]) -> PuzzleCacheKey? {
        var highestKey: PuzzleCacheKey?
        var highestLevel = 0

        for level in 1...lastLevelNumber {
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
        guard (1...lastLevelNumber).contains(level) else {
            return nil
        }

        if level <= 64 {
            let zeroBasedLevel = level - 1
            let difficultyCount = PuzzleDifficulty.allCases.count
            let blockCount = BoardPuzzle.blockCountRange.lowerBound + zeroBasedLevel / difficultyCount
            let difficultyIndex = zeroBasedLevel % difficultyCount

            guard
                let difficulty = PuzzleDifficulty.allCases.first(where: { $0.sortOrder == difficultyIndex }),
                BoardPuzzle.blockCountRange.contains(blockCount)
            else {
                return nil
            }

            return PuzzleCacheKey(level: level, blockCount: blockCount, difficulty: difficulty)
        }

        if level <= 100 {
            return PuzzleCacheKey(level: level, blockCount: 18, difficulty: .advanced)
        }

        return PuzzleCacheKey(level: level, blockCount: 20, difficulty: .advanced)
    }

    private static func levelNumber(blockCount: Int, difficulty: PuzzleDifficulty) -> Int {
        let difficultyCount = PuzzleDifficulty.allCases.count
        return (blockCount - BoardPuzzle.blockCountRange.lowerBound) * difficultyCount + difficulty.sortOrder + 1
    }

    private static func isUnlocked(
        _ key: PuzzleCacheKey,
        solvedCounts: [String: Int]
    ) -> Bool {
        guard (1...lastLevelNumber).contains(key.level) else {
            return false
        }

        guard solvedCounts[solvedCountKey(level: key.level), default: 0] == 0 else {
            return true
        }

        guard key.level > 1, let previousKey = puzzleKey(forLevel: key.level - 1) else {
            return true
        }

        return solvedCounts[solvedCountKey(level: previousKey.level), default: 0] >= clearRequirementValue(for: previousKey)
    }

    private static func completedPuzzleBucket(for key: PuzzleCacheKey) -> Int {
        key.level
    }

    private static func clearRequirementValue(for key: PuzzleCacheKey) -> Int {
        if key.level >= 101 {
            return 3
        }

        if key.level >= 65 {
            return 3
        }

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

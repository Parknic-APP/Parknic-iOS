import SwiftUI

/// 배지 획득 화면에 보여줄 값. 문구 계산을 화면 밖에 둬서 테스트할 수 있게 한다.
struct BadgeEarnedDisplay: Equatable {
    let result: CheckInResult
    /// 이 공원에서 받은 배지의 순번("4번째"). 알 수 없으면 nil
    let badgeNumberAtPark: Int?
    let characterAssetName: String?

    var parkName: String { result.badge.parkName }
    var type: ParkType { result.badge.parkType }
    var achievement: Achievement? { result.newAchievements.first }
    var ranking: WeeklyRankingSummary { result.weeklyRanking }
    var showsReviewButton: Bool { result.canWriteReview }

    var subtitle: String {
        guard let number = badgeNumberAtPark else { return parkName }
        return String(localized: "\(parkName) · 이 공원에서 \(number)번째 배지예요")
    }

    /// 순위 변동 표기. 색만으로 구분하지 않도록 기호를 함께 쓴다.
    var rankChangeText: String? {
        switch ranking.rankChange {
        case 1...: "▲\(ranking.rankChange)"
        case ..<0: "▼\(-ranking.rankChange)"
        default: nil
        }
    }

    var podiumText: String {
        ranking.rank <= 3
            ? String(localized: "시상대에 올랐어요")
            : String(localized: "시상대까지\n배지 \(ranking.badgesToPodium)개")
    }
}

/// 12d·06a — 배지 획득. 배지·캐릭터 이미지는 에셋 이름으로 참조하고, 없는 동안은 임시 도형을 쓴다.
struct BadgeEarnedView: View {
    let display: BadgeEarnedDisplay
    let onClose: () -> Void
    let onWriteReview: () -> Void
    let onShowRanking: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.leaf600.ignoresSafeArea()
            Confetti().ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: Spacing.s20) {
                topBar
                Spacer(minLength: 0)
                badge
                titles
                cards
                Spacer(minLength: 0)
                buttons
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s16)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true } }
        .sensoryFeedback(.success, trigger: appeared)
    }

    // MARK: 구성

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline).foregroundStyle(Color.white)
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .background(Color.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("닫기")
        }
        .padding(.top, Spacing.s8)
    }

    private var badge: some View {
        VStack(spacing: Spacing.s16) {
            Text("짠! 새 배지를 받았어요")
                .pkTextStyle(.headline).foregroundStyle(Color.white)
                .padding(.horizontal, Spacing.s16).frame(minHeight: 40)
                .background(Color.white.opacity(0.18), in: Capsule())
            ZStack {
                if UIImage(named: display.type.badgeAssetName) != nil {
                    Image(display.type.badgeAssetName).resizable().scaledToFit()
                } else {
                    Circle().fill(display.type.color)
                        .overlay(Circle().stroke(Color.ink900, lineWidth: 10))
                        .overlay(
                            Image(systemName: display.type.symbolName)
                                .font(.system(size: 96, weight: .semibold)).foregroundStyle(Color.ink900))
                }
            }
            .frame(width: 200, height: 200)
            .scaleEffect(appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)
        }
    }

    private var titles: some View {
        VStack(spacing: Spacing.s8) {
            Text("\(display.type.displayName) 배지").pkTextStyle(.display).foregroundStyle(Color.white)
            Text(display.subtitle).pkTextStyle(.body).foregroundStyle(Color.white.opacity(0.9))
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var cards: some View {
        VStack(spacing: Spacing.s12) {
            if let achievement = display.achievement { achievementCard(achievement) }
            rankingCard
        }
    }

    private func achievementCard(_ achievement: Achievement) -> some View {
        HStack(spacing: Spacing.s16) {
            ZStack {
                if UIImage(named: "achievement-\(achievement.code.lowercased())") != nil {
                    Image("achievement-\(achievement.code.lowercased())").resizable().scaledToFit()
                } else {
                    Circle().fill(Color.sun500).overlay(Image(systemName: "rosette").font(.title2).foregroundStyle(Color.ink900))
                }
            }
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                PKTag(text: "새 업적", symbol: "star.fill", style: .highlight)
                Text(achievement.name).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .combine)
    }

    private var rankingCard: some View {
        HStack(spacing: Spacing.s16) {
            PKIllustration(assetName: display.characterAssetName, fallbackSymbol: "pawprint.fill", size: 56)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("이번 주 \(display.parkName) 랭킹").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                HStack(spacing: Spacing.s8) {
                    Text("\(display.ranking.rank)위").pkTextStyle(.display).foregroundStyle(Color.ink900)
                    if let change = display.rankChangeText {
                        Text(change)
                            .pkTextStyle(.callout).foregroundStyle(display.ranking.rankChange > 0 ? Color.leaf600 : Color.danger600)
                            .padding(.horizontal, Spacing.s8).frame(minHeight: 28)
                            .background(display.ranking.rankChange > 0 ? Color.leaf100 : Color.danger100, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
            Text(display.podiumText)
                .pkTextStyle(.callout).foregroundStyle(Color.sun700).multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        HStack(spacing: Spacing.s12) {
            if display.showsReviewButton {
                Button("리뷰 쓰기", action: onWriteReview).buttonStyle(.pk(.tonal))
            }
            Button("랭킹 보기", action: onShowRanking).buttonStyle(.pk(.accent))
        }
    }
}

/// 축하 꽃가루(순수 장식이라 VoiceOver에서 숨긴다). 위에서 아래로 계속 흩날리고,
/// 하늘하늘 좌우로 흔들리며 뒤집히듯 회전한다. '동작 줄이기'를 켜면 가만히 흩뿌려 둔다.
struct Confetti: View {
    struct Piece: Equatable {
        enum Shape { case paper, dot, petal }

        let x: Double  // 0...1, 화면 폭 비율
        let start: Double  // 0...1, 처음 높이 비율(전체가 한꺼번에 떨어지지 않게 흩어 둔다)
        let speed: Double  // 낙하 속도(pt/s)
        let sway: Double  // 좌우로 흔들리는 폭(pt)
        let swayPeriod: Double
        let spin: Double  // 회전 속도(rad/s)
        let flipPeriod: Double  // 뒤집히는 주기(s)
        let phase: Double
        let size: Double
        let shape: Shape
        let colorIndex: Int
    }

    static let count = 24
    private static let palette: [Color] = [.sun500, .sun300, .leaf300, .leaf100, .white.opacity(0.9), .sun500, .leaf300]

    /// 항상 같은 배치가 나오도록 고정된 시드로 만든다(화면이 다시 그려져도 조각이 튀지 않는다).
    static let pieces: [Piece] = {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        let shapes: [Piece.Shape] = [.paper, .dot, .petal, .paper, .petal]
        return (0..<count).map { i in
            Piece(
                x: next(), start: next(), speed: 38 + next() * 52, sway: 10 + next() * 26,
                swayPeriod: 2.2 + next() * 2.4, spin: (next() - 0.5) * 5, flipPeriod: 1.2 + next() * 1.6,
                phase: next() * .pi * 2, size: 7 + next() * 7, shape: shapes[i % shapes.count],
                colorIndex: Int(next() * Double(palette.count)) % palette.count)
        }
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            canvas(time: 0)
        } else {
            TimelineView(.animation) { context in
                canvas(time: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            for piece in Self.pieces {
                draw(piece, in: &context, size: size, time: time)
            }
        }
    }

    /// 한 조각의 현재 위치(화면 밖으로 나가면 위에서 다시 내려온다). 테스트할 수 있게 따로 뺐다.
    static func position(of piece: Piece, in size: CGSize, time: Double) -> CGPoint {
        let margin = 24.0
        let travel = size.height + margin * 2
        let fall = (piece.start * travel + time * piece.speed).truncatingRemainder(dividingBy: travel)
        let drift = sin(time * 2 * .pi / piece.swayPeriod + piece.phase) * piece.sway
        return CGPoint(x: piece.x * size.width + drift, y: fall - margin)
    }

    private func draw(_ piece: Piece, in context: inout GraphicsContext, size: CGSize, time: Double) {
        let point = Self.position(of: piece, in: size, time: time)
        // 종이가 뒤집히듯 세로로 납작해졌다 펴진다.
        let flip = max(0.25, abs(cos(time * 2 * .pi / piece.flipPeriod + piece.phase)))
        var transform = CGAffineTransform(translationX: point.x, y: point.y)
        transform = transform.rotated(by: piece.phase + time * piece.spin).scaledBy(x: 1, y: flip)
        let rect: CGRect
        let path: Path
        switch piece.shape {
        case .paper:
            rect = CGRect(x: -piece.size, y: -piece.size * 0.32, width: piece.size * 2, height: piece.size * 0.64)
            path = Path(roundedRect: rect, cornerRadius: 2.5)
        case .dot:
            rect = CGRect(x: -piece.size * 0.4, y: -piece.size * 0.4, width: piece.size * 0.8, height: piece.size * 0.8)
            path = Path(ellipseIn: rect)
        case .petal:
            rect = CGRect(x: -piece.size * 0.8, y: -piece.size * 0.38, width: piece.size * 1.6, height: piece.size * 0.76)
            path = Path(ellipseIn: rect)
        }
        context.fill(path.applying(transform), with: .color(Self.palette[piece.colorIndex]))
    }
}

// MARK: - Preview

private let previewResult = CheckInResult(
    badge: EarnedBadge(parkID: 1024, parkName: "보라매공원", parkType: .neighborhood, earnedAt: Date()),
    newAchievements: [Achievement(code: "PARKS_10", name: "서로 다른 공원 10곳")],
    weeklyRanking: WeeklyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3),
    canWriteReview: true)

#Preview("업적 + 랭킹") {
    BadgeEarnedView(
        display: BadgeEarnedDisplay(result: previewResult, badgeNumberAtPark: 4, characterAssetName: nil),
        onClose: {}, onWriteReview: {}, onShowRanking: {})
}

#Preview("업적 없음 · 리뷰 불가 · 시상대") {
    BadgeEarnedView(
        display: BadgeEarnedDisplay(
            result: CheckInResult(
                badge: EarnedBadge(parkID: 1, parkName: "수변공원", parkType: .waterfront, earnedAt: Date()),
                newAchievements: [],
                weeklyRanking: WeeklyRankingSummary(rank: 2, badgeCount: 9, rankChange: -1, badgesToPodium: 0),
                canWriteReview: false),
            badgeNumberAtPark: nil, characterAssetName: nil),
        onClose: {}, onWriteReview: {}, onShowRanking: {})
}

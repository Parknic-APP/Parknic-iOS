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
    var ranking: MonthlyRankingSummary { result.monthlyRanking }
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
                Text("이달 \(display.parkName) 랭킹").pkTextStyle(.callout).foregroundStyle(Color.ink500)
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

/// 축하 장식(순수 장식이라 VoiceOver에서 숨긴다). 최종 일러스트로 교체할 수 있다.
private struct Confetti: View {
    private let pieces: [(x: CGFloat, y: CGFloat, color: Color, angle: Double)] = [
        (0.08, 0.18, .sun500, 20), (0.85, 0.12, .sun500, -15), (0.93, 0.42, .leaf300, 30), (0.05, 0.35, .leaf300, -10),
        (0.78, 0.62, .sun300, 40), (0.15, 0.58, .sun300, -35), (0.5, 0.05, .leaf100, 10), (0.9, 0.78, .sun500, -20),
        (0.12, 0.8, .leaf100, 25),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(pieces.indices, id: \.self) { index in
                let piece = pieces[index]
                RoundedRectangle(cornerRadius: 3).fill(piece.color)
                    .frame(width: 16, height: 10).rotationEffect(.degrees(piece.angle))
                    .position(x: proxy.size.width * piece.x, y: proxy.size.height * piece.y)
            }
        }
    }
}

// MARK: - Preview

private let previewResult = CheckInResult(
    badge: EarnedBadge(parkID: 1024, parkName: "보라매공원", parkType: .neighborhood, earnedAt: Date()),
    newAchievements: [Achievement(code: "PARKS_10", name: "서로 다른 공원 10곳")],
    monthlyRanking: MonthlyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3),
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
                monthlyRanking: MonthlyRankingSummary(rank: 2, badgeCount: 9, rankChange: -1, badgesToPodium: 0),
                canWriteReview: false),
            badgeNumberAtPark: nil, characterAssetName: nil),
        onClose: {}, onWriteReview: {}, onShowRanking: {})
}

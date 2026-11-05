import SwiftUI

/// 이달의 시상대(1~3등). 랭킹 화면과 공원 시트가 함께 쓴다. 빈 자리는 점선 단상으로 보여준다.
struct PodiumView: View {
    let ranking: ParkRanking
    /// 내 순위(나를 "(나)"로 표시)
    var myRank: Int?

    private let blockHeights: [Int: CGFloat] = [1: 112, 2: 76, 3: 56]

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s8) {
            column(rank: 2)
            column(rank: 1)
            column(rank: 3)
        }
        .frame(maxWidth: .infinity)
    }

    private func column(rank: Int) -> some View {
        let entry = ranking.podiumEntry(rank: rank)
        return VStack(spacing: Spacing.s4) {
            if let entry {
                PKIllustration(assetName: entry.characterAssetName, fallbackSymbol: "pawprint.fill", size: rank == 1 ? 84 : 68)
                Text(entry.rank == myRank ? "\(entry.nickname) (나)" : entry.nickname)
                    .pkTextStyle(.callout).foregroundStyle(Color.ink900).lineLimit(1)
                Text("배지 \(entry.badgeCount)개")
                    .pkTextStyle(.caption).foregroundStyle(Color.leaf600)
                    .padding(.horizontal, Spacing.s8).frame(minHeight: 22)
                    .background(Color.white, in: Capsule())
            } else {
                Circle()
                    .strokeBorder(Color.ink300, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: 60, height: 60)
                    .overlay(Text("?").pkTextStyle(.display).foregroundStyle(Color.ink300))
                Text("빈 자리").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                Text("도전해 보세요").pkTextStyle(.caption).foregroundStyle(Color.ink500)
            }
            block(rank: rank, isEmpty: entry == nil)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(rank: rank, entry: entry))
    }

    private func block(rank: Int, isEmpty: Bool) -> some View {
        let height = blockHeights[rank] ?? 56
        return ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: Radius.r20, topTrailingRadius: Radius.r20)
                .fill(isEmpty ? Color.clear : blockColor(rank))
            if isEmpty {
                UnevenRoundedRectangle(topLeadingRadius: Radius.r20, topTrailingRadius: Radius.r20)
                    .strokeBorder(Color.ink300, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            Text("\(rank)")
                .pkTextStyle(.display)
                .foregroundStyle(isEmpty ? Color.ink300 : Color.ink900)
                .padding(.top, Spacing.s8)
        }
        .frame(height: height)
    }

    // 색 + 숫자 + 높이로 구분한다(색만으로 순위를 전달하지 않는다).
    private func blockColor(_ rank: Int) -> Color {
        switch rank {
        case 1: .sun500
        case 2: Color.ink300.opacity(0.6)
        default: Color.sun300.opacity(0.7)
        }
    }

    private func accessibilityText(rank: Int, entry: RankingEntry?) -> String {
        guard let entry else { return String(localized: "\(rank)등 빈 자리") }
        return String(localized: "\(rank)등 \(entry.nickname), 배지 \(entry.badgeCount)개")
    }
}

#Preview("꽉 찬 시상대") {
    PodiumView(ranking: MockPodiumSample.full, myRank: nil)
        .padding().background(Color.leaf100)
}

#Preview("빈 자리 있음") {
    PodiumView(ranking: MockPodiumSample.nearlyEmpty)
        .padding().background(Color.leaf100)
}

private enum MockPodiumSample {
    static let full = ParkRanking(
        month: YearMonth(year: 2026, month: 10),
        podium: [
            RankingEntry(rank: 1, userID: 1, nickname: "두부산책", characterID: 5, badgeCount: 12),
            RankingEntry(rank: 2, userID: 2, nickname: "초록발", characterID: 3, badgeCount: 9),
            RankingEntry(rank: 3, userID: 3, nickname: "오리걸음", characterID: 8, badgeCount: 6),
        ], others: [], me: nil)
    static let nearlyEmpty = ParkRanking(
        month: YearMonth(year: 2026, month: 10),
        podium: [RankingEntry(rank: 1, userID: 1, nickname: "대방동주민", characterID: 4, badgeCount: 3)], others: [], me: nil)
}

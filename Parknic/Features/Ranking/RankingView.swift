import SwiftUI

/// 12g·08a·08b — 공원 주간 랭킹. 시상대 + 4위 이하 목록 + 하단 고정 내 순위.
struct RankingView: View {
    let viewModel: RankingViewModel
    var myCharacterAssetName: String?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                PKLoadingView(title: "랭킹을 불러오고 있어요")
            case .failed(let message):
                PKErrorView(
                    title: "랭킹을 불러오지 못했어요", message: LocalizedStringKey(message), retryTitle: "다시 시도",
                    onRetry: { Task { await viewModel.load() } })
            case .loaded(let ranking):
                content(ranking)
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("\(viewModel.parkName) 랭킹")
        .navigationBarTitleDisplayMode(.inline)
        .task { if viewModel.ranking == nil { await viewModel.load() } }
    }

    private func content(_ ranking: ParkRanking) -> some View {
        ScrollView {
            VStack(spacing: Spacing.s12) {
                weekSelector
                Text(viewModel.confirmationText).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                PodiumView(ranking: ranking, myRank: ranking.me?.rank)
                    .padding(Spacing.s16)
                    .background(Color.leaf100, in: RoundedRectangle(cornerRadius: Radius.r30))
                others(ranking)
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s20)
        }
        .safeAreaInset(edge: .bottom) { myFooter(ranking) }
    }

    private var weekSelector: some View {
        HStack(spacing: Spacing.s16) {
            Button { Task { await viewModel.showPreviousWeek() } } label: {
                Image(systemName: "chevron.left").frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
            }
            .accessibilityLabel("이전 주")
            Text(viewModel.week.rangeLabel)
                .pkTextStyle(.title2).foregroundStyle(Color.ink900)
            Button { Task { await viewModel.showNextWeek() } } label: {
                Image(systemName: "chevron.right").frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
            }
            .disabled(!viewModel.canGoNext)
            .opacity(viewModel.canGoNext ? 1 : 0.3)
            .accessibilityLabel("다음 주")
        }
        .foregroundStyle(Color.ink900)
        .padding(.horizontal, Spacing.s8)
        .background(Color.white, in: Capsule())
        .pkShadow(.soft1)
    }

    @ViewBuilder
    private func others(_ ranking: ParkRanking) -> some View {
        if ranking.others.isEmpty {
            Text("아직 4위 아래는 비어 있어요")
                .pkTextStyle(.body).foregroundStyle(Color.ink500)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        } else {
            VStack(spacing: 0) {
                ForEach(ranking.others) { entry in
                    row(entry, isMe: entry.rank == ranking.me?.rank)
                    if entry.id != ranking.others.last?.id { Divider().padding(.leading, Spacing.s20) }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        }
    }

    private func row(_ entry: RankingEntry, isMe: Bool) -> some View {
        HStack(spacing: Spacing.s16) {
            Text("\(entry.rank)").pkTextStyle(.title2).foregroundStyle(Color.ink500).frame(width: 32)
            PKIllustration(assetName: entry.characterAssetName, fallbackSymbol: "pawprint.fill", size: 44)
            Text(isMe ? "\(entry.nickname) (나)" : entry.nickname).pkTextStyle(.headline).foregroundStyle(Color.ink900)
            Spacer()
            Text("\(entry.badgeCount)개").pkTextStyle(.headline).foregroundStyle(Color.leaf600)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(minHeight: 60)
        .background(isMe ? Color.leaf50 : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.rank)등 \(entry.nickname), 배지 \(entry.badgeCount)개")
    }

    private func myFooter(_ ranking: ParkRanking) -> some View {
        let footer = MyRankingFooter.make(for: ranking)
        return HStack(spacing: Spacing.s12) {
            PKIllustration(assetName: myCharacterAssetName, fallbackSymbol: "pawprint.fill", size: 48)
                .padding(Spacing.s4).overlay(Circle().stroke(Color.leaf500, lineWidth: 2))
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(footer.title).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                Text(footer.subtitle).pkTextStyle(.callout).foregroundStyle(Color.sun700)
            }
            Spacer()
        }
        .padding(Spacing.s16)
        .background(
            Color.white.clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.r30, topTrailingRadius: Radius.r30))
                .pkShadow(.soft2).ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .combine)
    }
}

#Preview("랭킹") {
    NavigationStack {
        RankingView(
            viewModel: RankingViewModel(
                parkID: 1, parkName: "보라매공원", repository: MockRankingRepository(delay: .zero),
                initialState: .loaded(ParkRankingSample.full)))
    }
}

#Preview("시상대 거의 빔(08b)") {
    NavigationStack {
        RankingView(
            viewModel: RankingViewModel(
                parkID: 1, parkName: "대방소공원", repository: MockRankingRepository(delay: .zero),
                initialState: .loaded(ParkRankingSample.nearlyEmpty)))
    }
}

#Preview("로딩") {
    NavigationStack {
        RankingView(viewModel: RankingViewModel(parkID: 1, parkName: "보라매공원", repository: MockRankingRepository(delay: .seconds(60))))
    }
}

#Preview("에러") {
    NavigationStack {
        RankingView(
            viewModel: RankingViewModel(
                parkID: 1, parkName: "보라매공원", repository: MockRankingRepository(),
                initialState: .failed(APIError.network.userMessage)))
    }
}

private enum ParkRankingSample {
    static let week = RankingWeek(date: Calendar.kst.date(from: DateComponents(year: 2026, month: 11, day: 4)) ?? Date())
    static var full: ParkRanking {
        let names = ["두부산책", "초록발", "오리걸음", "구름빵", "솜사탕", "아침공기", "펭펭"]
        let counts = [12, 9, 6, 7, 6, 6, 5]
        let all = names.indices.map {
            RankingEntry(rank: $0 + 1, userID: $0 + 1, nickname: names[$0], characterID: ($0 % 8) + 1, badgeCount: counts[$0])
        }
        return ParkRanking(week: week, podium: Array(all.prefix(3)), others: Array(all.dropFirst(3)), me: MyRanking(rank: 17, badgeCount: 4))
    }
    static var nearlyEmpty: ParkRanking {
        ParkRanking(
            week: week, podium: [RankingEntry(rank: 1, userID: 1, nickname: "대방동주민", characterID: 4, badgeCount: 3)],
            others: [], me: MyRanking(rank: nil, badgeCount: 0))
    }
}

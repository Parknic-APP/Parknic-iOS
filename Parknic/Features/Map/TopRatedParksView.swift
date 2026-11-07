import SwiftUI

/// 리뷰가 좋은 공원 목록 시트. 공원을 누르면 지도에서 그 공원의 정보를 연다.
struct TopRatedParksView: View {
    let viewModel: TopRatedParksViewModel
    let onSelect: (Park) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            header
            switch viewModel.state {
            case .loading:
                ProgressView("리뷰 좋은 공원을 찾고 있어요")
                    .pkTextStyle(.callout)
                    .frame(maxWidth: .infinity, minHeight: 160)
            case .loaded(let parks):
                ScrollView {
                    LazyVStack(spacing: Spacing.s8) {
                        ForEach(parks) { row($0) }
                    }
                }
            case .empty:
                PKEmptyView(
                    title: "아직 조건에 맞는 공원이 없어요",
                    message: "리뷰가 10개 이상 모이고 별점이 4.5 이상인 공원이 생기면 여기에 보여요.",
                    symbol: "star")
            case .failed(let message):
                PKErrorView(
                    title: "목록을 불러오지 못했어요", message: LocalizedStringKey(message), retryTitle: "다시 시도",
                    onRetry: { Task { await viewModel.load() } })
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .task { if case .loading = viewModel.state { await viewModel.load() } }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("리뷰 좋은 공원").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                Text("내 주변 \(TopRatedPark.searchRadiusM / 1000)km · 리뷰 \(TopRatedPark.minReviewCount)개 이상 · 별점 \(TopRatedParksViewModel.ratingText(TopRatedPark.minRating)) 이상")
                    .pkTextStyle(.callout).foregroundStyle(Color.ink500)
            }
            Spacer(minLength: Spacing.s12)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Color.ink900)
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .background(Color.canvas, in: Circle())
            }
            .accessibilityLabel("닫기")
        }
    }

    private func row(_ item: TopRatedPark) -> some View {
        Button { onSelect(item.park) } label: {
            HStack(spacing: Spacing.s12) {
                Image(systemName: item.park.type.symbolName).foregroundStyle(Color.ink900)
                    .frame(width: 44, height: 44)
                    .background(item.park.type.color, in: RoundedRectangle(cornerRadius: Radius.r16))
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text(item.park.name).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                    HStack(spacing: Spacing.s4) {
                        Image(systemName: "star.fill").foregroundStyle(Color.sun500).imageScale(.small)
                        Text(TopRatedParksViewModel.ratingText(item.averageRating)).foregroundStyle(Color.ink900)
                        Text("리뷰 \(item.reviewCount)개").foregroundStyle(Color.ink500)
                    }
                    .pkTextStyle(.callout)
                }
                Spacer(minLength: Spacing.s8)
                VStack(alignment: .trailing, spacing: Spacing.s4) {
                    Text(DistanceFormatter.text(meters: item.distanceM)).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                    if item.park.badgeCount > 0 { PKTag(text: "배지 \(item.park.badgeCount)개", style: .highlight) }
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.ink300)
            }
            .padding(Spacing.s12)
            .frame(minHeight: 68)
            .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(item.park.name), 별점 \(TopRatedParksViewModel.ratingText(item.averageRating)), 리뷰 \(item.reviewCount)개, \(DistanceFormatter.text(meters: item.distanceM))")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

@MainActor
private func topRatedPreview(_ state: TopRatedParksViewModel.State) -> some View {
    TopRatedParksView(
        viewModel: TopRatedParksViewModel(
            repository: MockParkRepository(delay: .seconds(60)), center: Coordinate(latitude: 37.4934, longitude: 126.9209),
            initialState: state),
        onSelect: { _ in }, onClose: {})
}

#Preview("목록") {
    topRatedPreview(
        .loaded([
            TopRatedPark(park: MockParkRepository.sample[0], distanceM: 320, averageRating: 4.8, reviewCount: 128),
            TopRatedPark(park: MockParkRepository.sample[3], distanceM: 1250, averageRating: 4.6, reviewCount: 32),
            TopRatedPark(park: MockParkRepository.sample[1], distanceM: 4870, averageRating: 4.5, reviewCount: 10),
        ]))
}
#Preview("로딩") { topRatedPreview(.loading) }
#Preview("빈 상태") { topRatedPreview(.empty) }
#Preview("에러") { topRatedPreview(.failed(APIError.network.userMessage)) }

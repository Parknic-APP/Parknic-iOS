import SwiftUI

/// 12b·04a~04c — 공원 시트. 이번 주 시상대는 랭킹 작업에서 이 시트에 붙인다.
struct ParkSheetView: View {
    let viewModel: ParkSheetViewModel
    let availability: CheckInAvailability
    let isStartingCheckIn: Bool
    let distanceM: Int?
    let onCheckIn: () -> Void
    let onShowRanking: () -> Void
    let onShowReviews: () -> Void
    let onClose: () -> Void

    private static let topID = "parkSheetTop"

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                Color.clear.frame(height: 0).id(Self.topID)
                header
                stats
                checkInSection
                if let ranking = viewModel.ranking {
                    podiumSection(ranking)
                } else {
                    linkRow(symbol: "trophy", title: "이번 주 랭킹 보기", action: onShowRanking)
                }
                linkRow(symbol: "text.bubble", title: reviewTitle, action: onShowReviews)
                if case .failed(let message) = viewModel.state {
                    detailError(message)
                }
            }
            .padding(Spacing.s20)
        }
        // 시트가 열릴 때 항상 맨 위부터 보여준다.
        .onAppear { proxy.scrollTo(Self.topID, anchor: .top) }
        }
        .background(Color.white)
        .task {
            async let detail: Void = viewModel.load()
            async let ranking: Void = viewModel.loadRanking()
            _ = await (detail, ranking)
        }
    }

    // MARK: 구성

    private func podiumSection(_ ranking: ParkRanking) -> some View {
        VStack(spacing: Spacing.s12) {
            HStack {
                Text("이번 주 시상대").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                PKTag(text: LocalizedStringKey(ranking.week.shortLabel), style: .neutral)
                Spacer()
                Button(action: onShowRanking) {
                    HStack(spacing: Spacing.s4) {
                        Text("전체 랭킹")
                        Image(systemName: "chevron.right")
                    }
                    .pkTextStyle(.callout).foregroundStyle(Color.leaf600)
                    .frame(minHeight: TouchTarget.minimum)
                }
            }
            PodiumView(ranking: ranking, myRank: ranking.me?.rank)
            let footer = MyRankingFooter.make(for: ranking)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(footer.title).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                Text(footer.subtitle).pkTextStyle(.callout).foregroundStyle(Color.sun700)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r20))
        }
        .padding(Spacing.s16)
        .background(Color.leaf50, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s16) {
            Image(systemName: viewModel.park.type.symbolName)
                .font(.title)
                .foregroundStyle(Color.ink900)
                .frame(width: 64, height: 64)
                .background(viewModel.park.type.color, in: RoundedRectangle(cornerRadius: Radius.r20))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                PKTag(text: LocalizedStringKey(viewModel.park.type.displayName), style: .park(viewModel.park.type))
                Text(viewModel.park.name).pkTextStyle(.title1).foregroundStyle(Color.ink900)
                if let address = viewModel.detail?.address {
                    Text(address).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                }
                if let distanceText {
                    Label(distanceText, systemImage: isInsidePark ? "checkmark.circle.fill" : "location")
                        .pkTextStyle(.callout)
                        .foregroundStyle(isInsidePark ? Color.leaf600 : Color.ink500)
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.ink700)
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .background(Color.ink100, in: Circle())
            }
            .accessibilityLabel("닫기")
        }
    }

    /// 판정 반경 안이면 "지금 공원 안", 아니면 거리. (중심에서의 거리가 아니라 반경 안인지로 판단한다)
    private var isInsidePark: Bool {
        switch availability {
        case .available: true
        case .outOfRange: false
        default: (distanceM ?? .max) < 10
        }
    }

    private var distanceText: String? {
        guard let distanceM else { return nil }
        return isInsidePark ? String(localized: "지금 공원 안") : DistanceFormatter.text(meters: distanceM)
    }

    private var stats: some View {
        HStack(spacing: Spacing.s12) {
            statCard(title: "평균 별점") {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
                    Image(systemName: "star.fill").foregroundStyle(Color.sun500)
                    if let rating = viewModel.detail?.averageRating {
                        Text(String(format: "%.1f", rating)).pkTextStyle(.display).foregroundStyle(Color.ink900)
                    } else {
                        Text(viewModel.detail == nil ? "-" : String(localized: "아직 없어요"))
                            .pkTextStyle(.headline).foregroundStyle(Color.ink500)
                    }
                    if let count = viewModel.detail?.reviewCount, count > 0 {
                        Text("리뷰 \(count)").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                    }
                }
            }
            statCard(title: "내 배지") {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
                    Text("\(viewModel.park.badgeCount)").pkTextStyle(.display).foregroundStyle(Color.leaf600)
                    Text("개 모았어요").pkTextStyle(.callout).foregroundStyle(Color.ink700)
                }
            }
        }
    }

    private func statCard<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(title).pkTextStyle(.callout).foregroundStyle(Color.ink500)
            content()
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r20))
        .accessibilityElement(children: .combine)
    }

    // MARK: 체크인 버튼

    private var checkInSection: some View {
        VStack(spacing: Spacing.s8) {
            if availability == .earnedToday {
                // 04c — 버튼이 아니라 완료 표시
                Label("오늘 배지를 받았어요", systemImage: "checkmark")
                    .pkTextStyle(.headline).foregroundStyle(Color.sun700)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.sun100, in: RoundedRectangle(cornerRadius: Radius.r20))
            } else {
                Button(action: onCheckIn) {
                    if isStartingCheckIn {
                        ProgressView().tint(.white)
                    } else {
                        Label(buttonTitle, systemImage: availability.isEnabled ? "checkmark.shield" : "mappin.slash")
                    }
                }
                .buttonStyle(.pk(.primary))
                .disabled(!availability.isEnabled || isStartingCheckIn)
            }
            Text(hint).pkTextStyle(.callout).foregroundStyle(Color.ink500).multilineTextAlignment(.center)
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch availability {
        case .available: "여기서 체크인하기"
        case .inProgressHere: "체크인 진행 중 보기"
        default: "체크인하기"
        }
    }

    private var hint: LocalizedStringKey {
        switch availability {
        case .available: "공원 안에 있어요 · 20분 머무르면 배지를 받아요"
        case .outOfRange(let distance): "공원 안에서 체크인할 수 있어요 · 지금 \(DistanceFormatter.text(meters: distance))"
        case .earnedToday: "같은 공원은 하루 1개 · 내일 또 받을 수 있어요"
        case .waitingForLocation: "내 위치를 확인하고 있어요"
        case .locationDenied: "위치 권한을 켜면 체크인할 수 있어요"
        case .inProgressHere: "지금 이 공원에서 산책 중이에요"
        case .anotherInProgress(let name): "\(name)에서 체크인 중이에요 · 동시에 한 곳만 할 수 있어요"
        }
    }

    // MARK: 이동 행·에러

    private var reviewTitle: LocalizedStringKey {
        if let count = viewModel.detail?.reviewCount, count > 0 { return "리뷰 \(count)개 보기" }
        return "리뷰 보기"
    }

    private func linkRow(symbol: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.ink300)
            }
            .padding(.horizontal, Spacing.s16)
            .frame(minHeight: 56)
            .background(Color.leaf50, in: RoundedRectangle(cornerRadius: Radius.r20))
        }
    }

    private func detailError(_ message: String) -> some View {
        HStack {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .pkTextStyle(.callout).foregroundStyle(Color.danger600)
            Spacer()
            Button("다시 시도") { Task { await viewModel.load() } }
                .buttonStyle(.pk(.tonal, size: .small, fillsWidth: false))
        }
    }
}

// MARK: - 반경이 겹칠 때 공원 고르기

/// 판정 반경이 겹치는 위치에서는 체크인할 공원을 사용자가 고른다.
struct ParkChooserSheet: View {
    let parks: [Park]
    let location: Coordinate?
    var title: LocalizedStringKey = "어느 공원에서 체크인할까요?"
    var message: LocalizedStringKey = "여러 공원의 범위가 겹쳐 있어요. 한 곳만 고를 수 있어요."
    var cancelTitle: LocalizedStringKey = "취소"
    let onSelect: (Park) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Text(title).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            Text(message).pkTextStyle(.body).foregroundStyle(Color.ink500)
            ForEach(parks) { park in
                Button { onSelect(park) } label: {
                    HStack(spacing: Spacing.s12) {
                        Image(systemName: park.type.symbolName).foregroundStyle(Color.ink900)
                            .frame(width: 44, height: 44)
                            .background(park.type.color, in: RoundedRectangle(cornerRadius: Radius.r16))
                        VStack(alignment: .leading, spacing: Spacing.s4) {
                            Text(park.name).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                            Text(park.type.displayName).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                        }
                        Spacer()
                        if let location {
                            Text(DistanceFormatter.text(meters: Int(park.coordinate.distance(to: location).rounded())))
                                .pkTextStyle(.callout).foregroundStyle(Color.ink500)
                        }
                    }
                    .padding(Spacing.s12)
                    .frame(minHeight: 64)
                    .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r20))
                }
            }
            Button(cancelTitle, action: onCancel).buttonStyle(.pk(.secondary))
        }
        .padding(Spacing.s20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}

// MARK: - Preview

@MainActor
private func sheet(
    _ park: Park, _ availability: CheckInAvailability, distance: Int? = 320, starting: Bool = false
) -> some View {
    ParkSheetView(
        viewModel: ParkSheetViewModel(
            park: park, repository: MockParkRepository(delay: .zero),
            initialState: .loaded(ParkDetail(park: park, address: "동작구 여의대방로20길 33", averageRating: 4.6, reviewCount: 128))),
        availability: availability, isStartingCheckIn: starting, distanceM: distance,
        onCheckIn: {}, onShowRanking: {}, onShowReviews: {}, onClose: {})
}

#Preview("체크인 가능(04a)") { sheet(MockParkRepository.sample[0], .available, distance: 3) }
#Preview("반경 밖(04b)") { sheet(MockParkRepository.sample[1], .outOfRange(distanceM: 870), distance: 870) }
#Preview("오늘 획득(04c)") { sheet(MockParkRepository.sample[3], .earnedToday, distance: 510) }
#Preview("다른 공원 체크인 중") { sheet(MockParkRepository.sample[1], .anotherInProgress(parkName: "보라매공원")) }
#Preview("시작 중") { sheet(MockParkRepository.sample[0], .available, distance: 3, starting: true) }
#Preview("공원 고르기") {
    ParkChooserSheet(
        parks: Array(MockParkRepository.sample.prefix(2)), location: Coordinate(latitude: 37.4934, longitude: 126.9209),
        onSelect: { _ in }, onCancel: {})
}

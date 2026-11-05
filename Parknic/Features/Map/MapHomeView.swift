import SwiftUI

/// 12a·03a·03c — 지도 홈. 공원 시트는 다음 작업에서 `selectedPark`에 연결한다.
struct MapHomeView: View {
    @Bindable var viewModel: MapHomeViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            if viewModel.showsLocationDenied {
                LocationDeniedView(onOpenSettings: openSettings, onBrowse: viewModel.browseWithoutLocation)
            } else {
                mapLayer
            }
        }
        .task { await viewModel.run() }
        .onChange(of: viewModel.checkIn.state) { _, state in viewModel.checkInStateDidChange(state) }
        .sheet(item: parkBinding) { park in
            ParkSheetHost(park: park, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.r30)
        }
        .fullScreenCover(isPresented: $viewModel.showsCheckInFlow) {
            CheckInFlowView(
                coordinator: viewModel.checkIn, parkType: viewModel.checkInParkType,
                badgeNumberAtPark: viewModel.badgeNumberAtPark, characterAssetName: viewModel.characterAssetName,
                onWriteReview: viewModel.openParkAfterBadge, onShowRanking: viewModel.openParkAfterBadge,
                onRetry: { viewModel.retryCheckIn(parkID: lastParkID) },
                onBackToMap: { viewModel.showsCheckInFlow = false })
        }
        .alert("체크인을 시작하지 못했어요", isPresented: startErrorBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.startErrorMessage ?? "")
        }
    }

    private var parkBinding: Binding<Park?> {
        Binding(
            get: { viewModel.selectedPark },
            set: { if $0 == nil { viewModel.selectedParkID = nil } })
    }

    private var startErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.startErrorMessage != nil },
            set: { if !$0 { viewModel.startErrorMessage = nil } })
    }

    /// 실패 화면에서 「다시 체크인하기」를 누를 때 열 공원
    private var lastParkID: Int? { viewModel.checkIn.state.session?.parkID }

    private var mapLayer: some View {
        ZStack {
            ParkMapView(
                parks: viewModel.nearby.parks, userLocation: viewModel.nearby.currentLocation,
                selectedParkID: viewModel.selectedParkID, recenterToken: viewModel.recenterToken,
                onSelect: { viewModel.selectedParkID = $0.id })
            VStack {
                if let display = viewModel.checkInDisplay, !viewModel.showsCheckInFlow {
                    CheckInBanner(display: display) { viewModel.showsCheckInFlow = true }
                }
                summaryPill
                if viewModel.isBrowsingWithoutLocation { permissionBanner }
                Spacer()
                HStack(alignment: .bottom) {
                    legend
                    Spacer()
                    locateButton
                }
            }
            .padding(Spacing.s16)
            stateOverlay
        }
    }

    // MARK: 구성

    private var summaryPill: some View {
        Label {
            HStack(spacing: Spacing.s4) {
                Text("내 주변 1km").foregroundStyle(Color.ink900)
                Text("공원 \(viewModel.nearby.parks.count)곳").foregroundStyle(Color.leaf600)
            }
            .pkTextStyle(.headline)
        } icon: {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.leaf600)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(minHeight: TouchTarget.minimum)
        .background(Color.white, in: Capsule())
        .pkShadow(.soft2)
        .accessibilityElement(children: .combine)
    }

    private var permissionBanner: some View {
        Button(action: openSettings) {
            Label("위치 권한이 꺼져 있어요 · 설정에서 켜기", systemImage: "location.slash")
                .pkTextStyle(.callout).foregroundStyle(Color.danger600)
                .padding(.horizontal, Spacing.s16).frame(minHeight: TouchTarget.minimum)
                .background(Color.danger100, in: Capsule())
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            legendRow(color: .white, border: .ink300, text: "아직 안 받은 공원")
            legendRow(color: .leaf600, border: .leaf600, text: "배지 받은 공원")
            legendRow(color: .sun500, border: .sun700, text: "오늘 받은 공원")
        }
        .padding(Spacing.s12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r16))
        .pkShadow(.soft1)
        .accessibilityElement(children: .combine)
    }

    private func legendRow(color: Color, border: Color, text: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.s8) {
            RoundedRectangle(cornerRadius: Radius.r8).fill(color)
                .overlay(RoundedRectangle(cornerRadius: Radius.r8).stroke(border, lineWidth: 1.5))
                .frame(width: 16, height: 16)
            Text(text).pkTextStyle(.callout).foregroundStyle(Color.ink900)
        }
    }

    private var locateButton: some View {
        Button(action: viewModel.recenter) {
            Image(systemName: "location.fill")
                .font(.title3).foregroundStyle(Color.leaf600)
                .frame(width: 52, height: 52).background(Color.white, in: Circle()).pkShadow(.soft2)
        }
        .accessibilityLabel("내 위치로 이동")
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.nearby.state {
        case .loading where viewModel.nearby.currentLocation != nil:
            ProgressView("주변 공원을 찾고 있어요")
                .pkTextStyle(.callout).padding(Spacing.s16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r16)).pkShadow(.soft2)
        case .empty:
            // 03c — 1km 안에 공원이 없다
            statusCard(
                title: "근처 1km 안에 공원이 없어요", message: "다른 동네로 이동하면 공원이 나타나요.",
                symbol: "leaf", actionTitle: nil, action: nil)
        case .failed(let message):
            statusCard(
                title: "공원을 불러오지 못했어요", message: LocalizedStringKey(message), symbol: "wifi.slash",
                actionTitle: "다시 시도", action: viewModel.nearby.retry)
        default:
            EmptyView()
        }
    }

    private func statusCard(
        title: LocalizedStringKey, message: LocalizedStringKey, symbol: String, actionTitle: LocalizedStringKey?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: Spacing.s12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Color.leaf600)
            Text(title).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            Text(message).pkTextStyle(.body).foregroundStyle(Color.ink500).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Label(actionTitle, systemImage: "arrow.clockwise") }
                    .buttonStyle(.pk(.primary, size: .medium, fillsWidth: false))
            }
        }
        .padding(Spacing.s20)
        .frame(maxWidth: 320)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        .pkShadow(.soft2)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// 공원 시트 한 번의 표시 동안 같은 ViewModel을 유지하고, 반경이 겹칠 때의 선택 시트를 위에 띄운다.
private struct ParkSheetHost: View {
    let park: Park
    let viewModel: MapHomeViewModel
    @State private var sheetModel: ParkSheetViewModel

    init(park: Park, viewModel: MapHomeViewModel) {
        self.park = park
        self.viewModel = viewModel
        _sheetModel = State(initialValue: viewModel.makeSheetViewModel(for: park))
    }

    var body: some View {
        // 목록이 새로 조회되면 최신 상태(오늘 받음 등)로 보여준다.
        let current = viewModel.nearby.parks.first { $0.id == park.id } ?? park
        ParkSheetView(
            viewModel: sheetModel, availability: viewModel.availability(for: current),
            isStartingCheckIn: viewModel.isStartingCheckIn, distanceM: viewModel.distanceM(to: current),
            onCheckIn: { Task { await viewModel.checkInTapped(on: current) } },
            onShowRanking: {}, onShowReviews: {}, onClose: { viewModel.selectedParkID = nil })
            .sheet(isPresented: chooserBinding) {
                ParkChooserSheet(
                    parks: viewModel.chooserParks ?? [], location: viewModel.nearby.currentLocation,
                    onSelect: { chosen in Task { await viewModel.chooseForCheckIn(chosen) } },
                    onCancel: { viewModel.chooserParks = nil })
                    .presentationDetents([.medium])
            }
    }

    private var chooserBinding: Binding<Bool> {
        Binding(
            get: { viewModel.chooserParks != nil },
            set: { if !$0 { viewModel.chooserParks = nil } })
    }
}

// MARK: - Preview

private struct PreviewLocation: LocationProviding {
    var authorization: LocationAuthorization = .authorized
    func events() -> AsyncStream<LocationEvent> {
        AsyncStream { continuation in
            continuation.yield(.authorization(authorization))
            if authorization == .authorized { continuation.yield(.location(Coordinate(latitude: 37.4934, longitude: 126.9209))) }
        }
    }
    func requestPermissionIfNeeded() {}
}

@MainActor
private func previewModel(
    _ state: NearbyParksViewModel.State, authorization: LocationAuthorization = .authorized
) -> MapHomeViewModel {
    MapHomeViewModel(
        location: PreviewLocation(authorization: authorization),
        nearby: NearbyParksViewModel(repository: MockParkRepository(delay: .seconds(60)), initialState: state),
        checkIn: CheckInCoordinator(
            repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(),
            store: UserDefaultsCheckInStore()),
        parks: MockParkRepository(delay: .zero))
}

#Preview("공원 있음") { MapHomeView(viewModel: previewModel(.loaded(MockParkRepository.sample))) }
#Preview("공원 없음") { MapHomeView(viewModel: previewModel(.empty)) }
#Preview("에러") { MapHomeView(viewModel: previewModel(.failed(APIError.network.userMessage))) }
#Preview("권한 거부") { MapHomeView(viewModel: previewModel(.loading, authorization: .denied)) }

import SwiftUI

/// 탭 구성: 지도(홈) / 도감 / 마이. 각 탭은 해당 기능 구현 전까지 빈 상태 자리표시자다.
struct RootTabView: View {
    let mapViewModel: MapHomeViewModel
    let myPageViewModel: MyPageViewModel

    var body: some View {
        TabView {
            MapHomeView(viewModel: mapViewModel)
                .tabItem { Label("지도", systemImage: "map") }
            // 도감(배지 수집)은 P1이라 1차 출시에서는 탭을 두지 않는다.
            MyPageView(viewModel: myPageViewModel)
                .tabItem { Label("마이", systemImage: "person") }
        }
        .tint(.leaf600)
    }
}

#Preview {
    RootTabView(
        mapViewModel: MapHomeViewModel(
            location: CoreLocationProvider(), nearby: NearbyParksViewModel(repository: MockParkRepository()),
            checkIn: CheckInCoordinator(
                repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(),
                store: UserDefaultsCheckInStore()),
            parks: MockParkRepository()),
        myPageViewModel: MyPageViewModel(
            auth: MockAuthRepository(), profile: UserDefaultsProfileStore(), isCheckInActive: { false }, onSignedOut: {}))
}

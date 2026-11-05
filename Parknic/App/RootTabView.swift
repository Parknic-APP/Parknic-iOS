import SwiftUI

/// 탭 구성: 지도(홈) / 도감 / 마이. 각 탭은 해당 기능 구현 전까지 빈 상태 자리표시자다.
struct RootTabView: View {
    let mapViewModel: MapHomeViewModel

    var body: some View {
        TabView {
            MapHomeView(viewModel: mapViewModel)
                .tabItem { Label("지도", systemImage: "map") }
            placeholder(title: "도감")
                .tabItem { Label("도감", systemImage: "rosette") }
            placeholder(title: "마이")
                .tabItem { Label("마이", systemImage: "person") }
        }
        .tint(.leaf600)
    }

    private func placeholder(title: LocalizedStringKey) -> some View {
        PKEmptyView(title: title, message: "준비 중이에요")
    }
}

#Preview {
    RootTabView(
        mapViewModel: MapHomeViewModel(
            location: CoreLocationProvider(), nearby: NearbyParksViewModel(repository: MockParkRepository())))
}

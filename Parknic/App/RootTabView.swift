import SwiftUI

/// 탭 구성: 지도(홈) / 도감 / 마이페이지. 하단 바는 시스템 탭바 대신 디자인(12a·12h·12i)대로 직접 그린다.
struct RootTabView: View {
    enum Tab: Hashable, CaseIterable {
        case map, collection, myPage

        var title: LocalizedStringKey {
            switch self {
            case .map: "지도"
            case .collection: "도감"
            case .myPage: "마이페이지"
            }
        }

        func symbol(selected: Bool) -> String {
            switch self {
            case .map: selected ? "map.fill" : "map"
            case .collection: selected ? "book.closed.fill" : "book.closed"
            case .myPage: selected ? "person.fill" : "person"
            }
        }
    }

    let mapViewModel: MapHomeViewModel
    let collectionViewModel: CollectionViewModel
    let myPageViewModel: MyPageViewModel

    @State private var selection: Tab = .map
    /// 마이페이지 탭을 다시 누를 때마다 올라간다. 쌓여 있던 화면(내 리뷰 등)을 닫고 마이페이지 첫 화면으로 돌아가게 한다.
    @State private var myPageResetToken = 0

    var body: some View {
        // `safeAreaInset`은 탭 안쪽 화면(지도 범례 등)에 전달되지 않아 탭바 뒤로 가려지므로 위아래로 쌓는다.
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                MapHomeView(viewModel: mapViewModel)
                    .tag(Tab.map)
                    .toolbar(.hidden, for: .tabBar)
                CollectionView(viewModel: collectionViewModel)
                    .tag(Tab.collection)
                    .toolbar(.hidden, for: .tabBar)
                MyPageView(viewModel: myPageViewModel, resetToken: myPageResetToken, onShowCollection: { selection = .collection })
                    .tag(Tab.myPage)
                    .toolbar(.hidden, for: .tabBar)
            }
            PKTabBar(selection: $selection) { tab in
                // 이미 선택된 탭을 다시 눌렀을 때
                if tab == .myPage { myPageResetToken += 1 }
            }
        }
    }
}

/// 흰 바탕 + 위쪽 얇은 선. 선택된 탭은 `leaf600` 채운 아이콘, 나머지는 `ink500`.
private struct PKTabBar: View {
    @Binding var selection: RootTabView.Tab
    /// 이미 선택된 탭을 다시 눌렀다.
    var onReselect: (RootTabView.Tab) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTabView.Tab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    if tab == selection { onReselect(tab) } else { selection = tab }
                } label: {
                    VStack(spacing: Spacing.s4) {
                        Image(systemName: tab.symbol(selected: isSelected)).font(.system(size: 24)).frame(height: 28)
                        Text(tab.title).pkTextStyle(.caption)
                    }
                    .foregroundStyle(isSelected ? Color.leaf600 : Color.ink500)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, Spacing.s4)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.ink100).frame(height: 1) }
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
        collectionViewModel: CollectionViewModel(repository: MockCollectionRepository(delay: .zero)),
        myPageViewModel: MyPageViewModel(
            auth: MockAuthRepository(), profile: UserDefaultsProfileStore(), repository: MockMyPageRepository(delay: .zero),
            userRepository: MockUserRepository(),
            isCheckInActive: { false }, onSignedOut: {}))
}

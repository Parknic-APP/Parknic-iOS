import SwiftUI

/// 12i·09b·09c — 마이페이지. 심사 필수 항목(로그아웃, 앱 안 회원 탈퇴, 약관·개인정보 링크)을 포함한다.
struct MyPageView: View {
    @Bindable var viewModel: MyPageViewModel
    /// 「총 배지」를 눌렀을 때 도감 탭으로 이동한다.
    var onShowCollection: (() -> Void)?
    @Environment(\.openURL) private var openURL

    @State private var confirmsLogout = false
    @State private var withdrawStep: WithdrawStep?
    @State private var reviewsModel: MyReviewsViewModel?
    @State private var openedReview: OpenedMyReview?
    @State private var profileEdit: ProfileEditViewModel?

    private enum WithdrawStep: Identifiable {
        case explain, final
        var id: Int { self == .explain ? 1 : 2 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s20) {
                    Text("마이페이지").pkTextStyle(.display).foregroundStyle(Color.ink900)
                    profileCard
                    summarySections
                    Text("설정").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                    settingsCard
                    accountCard
                    if viewModel.blocksAccountActions {
                        Label("체크인 중에는 로그아웃하거나 탈퇴할 수 없어요", systemImage: "info.circle")
                            .pkTextStyle(.callout).foregroundStyle(Color.ink500)
                    }
                    if let message = viewModel.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .pkTextStyle(.callout).foregroundStyle(Color.danger600)
                    }
                    Text(viewModel.appVersion)
                        .pkTextStyle(.callout).foregroundStyle(Color.ink500).frame(maxWidth: .infinity)
                }
                .padding(Spacing.s16)
            }
            .background(Color.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: reviewsBinding) {
                if let reviewsModel {
                    MyReviewsView(viewModel: reviewsModel, makeReviewList: viewModel.makeReviewListViewModel(for:))
                }
            }
            .navigationDestination(isPresented: openedReviewBinding) {
                if let openedReview { ReviewListView(viewModel: openedReview.viewModel, focusReviewID: openedReview.focusReviewID) }
            }
        }
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: profileEditBinding) {
            if let profileEdit { ProfileEditView(viewModel: profileEdit) { self.profileEdit = nil } }
        }
        .overlay { if viewModel.isWorking { ProgressView().controlSize(.large).tint(.leaf600) } }
        .alert("로그아웃할까요?", isPresented: $confirmsLogout) {
            Button("로그아웃", role: .destructive) { Task { await viewModel.logout() } }
            Button("취소", role: .cancel) {}
        }
        .alert("회원 탈퇴", isPresented: withdrawBinding(.explain)) {
            Button("계속하기", role: .destructive) { withdrawStep = .final }
            Button("취소", role: .cancel) {}
        } message: {
            Text("탈퇴하면 배지, 랭킹 기록, 작성한 리뷰 등 모든 정보가 사라지고 되돌릴 수 없어요.")
        }
        .alert("정말 탈퇴할까요?", isPresented: withdrawBinding(.final)) {
            Button("탈퇴하기", role: .destructive) { Task { await viewModel.deleteAccount() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("마지막 확인이에요. 탈퇴하면 같은 계정으로 다시 가입해도 기록을 되찾을 수 없어요.")
        }
    }

    // MARK: 구성

    private var profileCard: some View {
        HStack(spacing: Spacing.s12) {
            HStack(spacing: Spacing.s16) {
                PKIllustration(assetName: viewModel.characterAssetName, fallbackSymbol: "pawprint.fill", size: 72)
                    .padding(Spacing.s4).background(Color.leaf100, in: Circle())
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text(viewModel.nickname).pkTextStyle(.title1).foregroundStyle(Color.ink900)
                    Text(viewModel.subtitle).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button("수정", action: startProfileEdit)
                .buttonStyle(.pk(.tonal, size: .small, fillsWidth: false))
                .accessibilityHint("닉네임과 캐릭터를 바꿔요")
        }
        .padding(Spacing.s20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r30))
    }

    private func startProfileEdit() {
        profileEdit = viewModel.makeProfileEditViewModel {
            profileEdit = nil
            Task { await viewModel.load() }
        }
    }

    private var profileEditBinding: Binding<Bool> {
        Binding(get: { profileEdit != nil }, set: { if !$0 { profileEdit = nil } })
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            row("알림", detail: notificationDetail, action: openSystemSettings)
            Divider()
            row("위치 권한", detail: "앱을 사용하는 동안", action: openSystemSettings)
            Divider()
            row("이용약관") { openURL(AppConfig.termsURL) }
            Divider()
            row("개인정보 처리방침") { openURL(AppConfig.privacyPolicyURL) }
        }
        .padding(.horizontal, Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private var notificationDetail: LocalizedStringKey {
        switch viewModel.notificationsEnabled {
        case true?: "켜짐"
        case false?: "꺼짐"
        case nil: "설정에서 바꾸기"
        }
    }

    // MARK: 통계·내 리뷰

    @ViewBuilder
    private var summarySections: some View {
        switch viewModel.summaryState {
        case .loading:
            ProgressView().tint(.leaf600).frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let message):
            VStack(spacing: Spacing.s12) {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .pkTextStyle(.callout).foregroundStyle(Color.danger600)
                Button("다시 시도") { Task { await viewModel.load() } }.buttonStyle(.pk(.tonal))
            }
            .padding(Spacing.s20)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        case .loaded(let summary):
            statsGrid(summary.stats)
            reviewsSection(summary.recentReviews)
        }
    }

    private func statsGrid(_ stats: UserStats) -> some View {
        Grid(horizontalSpacing: Spacing.s12, verticalSpacing: Spacing.s12) {
            GridRow {
                Button { onShowCollection?() } label: {
                    statCard("총 배지", value: stats.totalBadges, unit: "개", valueColor: .leaf600, showsChevron: onShowCollection != nil)
                }
                .buttonStyle(.plain)
                .disabled(onShowCollection == nil)
                .accessibilityHint(onShowCollection == nil ? "" : "도감으로 이동해요")
                statCard("방문한 공원", value: stats.visitedParks, unit: "곳")
            }
            GridRow {
                statCard(
                    "연속 산책", value: stats.currentStreak, unit: "일", note: "최고 \(stats.bestStreak)일",
                    labelColor: .sun700, background: .sun100)
                statCard("시상대에 오른 공원", value: stats.podiumParks, unit: "곳")
            }
        }
    }

    private func statCard(
        _ title: LocalizedStringKey, value: Int, unit: LocalizedStringKey, note: String? = nil,
        valueColor: Color = .ink900, labelColor: Color = .ink500, background: Color = .white, showsChevron: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(title).pkTextStyle(.callout).foregroundStyle(labelColor)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
                Text("\(value)").pkTextStyle(.display).foregroundStyle(valueColor)
                Text(unit).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                if let note { Text(note).pkTextStyle(.callout).foregroundStyle(labelColor) }
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.r24))
        .overlay(alignment: .topTrailing) {
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.ink300).padding(Spacing.s16)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .combine)
    }

    private func reviewsSection(_ page: MyReviewPage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("내 리뷰").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                Text("\(page.totalCount)").pkTextStyle(.title2).foregroundStyle(Color.ink500)
                Spacer()
                if page.totalCount > 0 {
                    Button { reviewsModel = viewModel.makeReviewsViewModel() } label: {
                        HStack(spacing: Spacing.s4) {
                            Text("전체")
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .pkTextStyle(.callout).foregroundStyle(Color.leaf600)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            if viewModel.recentReviews.isEmpty {
                Text("아직 쓴 리뷰가 없어요. 공원에서 배지를 받으면 리뷰를 남길 수 있어요")
                    .pkTextStyle(.body).foregroundStyle(Color.ink500)
                    .padding(Spacing.s20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentReviews.enumerated()), id: \.element.id) { index, review in
                        if index > 0 { Divider() }
                        Button {
                            openedReview = OpenedMyReview(viewModel: viewModel.makeReviewListViewModel(for: review), focusReviewID: review.id)
                        } label: {
                            MyReviewRow(review: review, timeText: viewModel.relativeTime(of: review)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("그 공원의 리뷰로 이동해요")
                    }
                }
                .padding(.horizontal, Spacing.s16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            }
        }
    }

    private var openedReviewBinding: Binding<Bool> {
        Binding(get: { openedReview != nil }, set: { if !$0 { openedReview = nil } })
    }

    private var reviewsBinding: Binding<Bool> {
        Binding(get: { reviewsModel != nil }, set: { if !$0 { reviewsModel = nil } })
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            Button { confirmsLogout = true } label: {
                Text("로그아웃").pkTextStyle(.headline).foregroundStyle(Color.ink700)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 56)
            }
            Divider()
            Button { withdrawStep = .explain } label: {
                Text("회원 탈퇴").pkTextStyle(.headline).foregroundStyle(Color.danger600)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 56)
            }
        }
        .disabled(viewModel.blocksAccountActions || viewModel.isWorking)
        .padding(.horizontal, Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private func row(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                Spacer()
                if let detail { Text(detail).pkTextStyle(.callout).foregroundStyle(Color.ink500) }
                Image(systemName: "chevron.right").foregroundStyle(Color.ink300)
            }
            .frame(minHeight: 56)
        }
    }

    private func withdrawBinding(_ step: WithdrawStep) -> Binding<Bool> {
        Binding(get: { withdrawStep?.id == step.id }, set: { if !$0, withdrawStep?.id == step.id { withdrawStep = nil } })
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

// MARK: - Preview

private struct PreviewAuth: AuthRepository {
    func login(provider: AuthProvider, socialToken: String, authorizationCode: String?) async throws -> LoginResult { LoginResult(isNewUser: false) }
    func logout() async {}
    func deleteAccount() async throws {}
}

private struct PreviewNotificationStatus: NotificationStatusReading {
    func isEnabled() async -> Bool { true }
}

@MainActor
private func previewModel(
    checkInActive: Bool = false, repository: MockMyPageRepository = MockMyPageRepository(delay: .zero),
    initialState: MyPageViewModel.SummaryState = .loading
) -> MyPageViewModel {
    MyPageViewModel(
        auth: PreviewAuth(), profile: UserDefaultsProfileStore(), repository: repository,
        userRepository: MockUserRepository(),
        notificationStatus: PreviewNotificationStatus(), initialState: initialState,
        isCheckInActive: { checkInActive }, onSignedOut: {})
}

#Preview("기본") { MyPageView(viewModel: previewModel()) }
#Preview("체크인 중") { MyPageView(viewModel: previewModel(checkInActive: true)) }
#Preview("신규 회원(기록 없음)") {
    MyPageView(viewModel: previewModel(repository: MockMyPageRepository(delay: .zero, isNewcomer: true)))
}
#Preview("불러오기 실패") {
    MyPageView(
        viewModel: previewModel(
            repository: MockMyPageRepository(delay: .zero, failure: .network),
            initialState: .failed(APIError.network.userMessage)))
}

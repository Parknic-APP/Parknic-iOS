import SwiftUI

/// 07e — 권한 안내. 시스템 권한 창 전에 왜 필요한지 먼저 설명한다.
struct PermissionGuideView: View {
    let viewModel: PermissionGuideViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s20) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text("공원에 머문 시간을 재려면\n두 가지가 필요해요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text("다음 화면에서 iPhone이 허용 여부를 물어봐요").pkTextStyle(.body).foregroundStyle(Color.ink500)
            }
            VStack(spacing: Spacing.s12) {
                PermissionCard(
                    symbol: "mappin.and.ellipse", title: "위치", badge: "'앱을 사용하는 동안' 허용",
                    message: "앱을 닫아도 20분을 이어서 셀 수 있어요. 공원 반경 안에 있는지만 확인해요.",
                    tint: .leaf600, background: .leaf50)
                PermissionCard(
                    symbol: "bell", title: "알림", badge: nil,
                    message: "공원을 벗어나면 바로 알려드려서 1분 안에 돌아올 수 있어요. 배지 소식도 알려드려요.",
                    tint: .sun700, background: .sun100)
                privacyNote
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.top, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .safeAreaInset(edge: .bottom) { actions }
    }

    private var privacyNote: some View {
        Label("위치는 체크인 중에만 쓰고, 이동 경로는 저장하지 않아요", systemImage: "lock")
            .pkTextStyle(.callout)
            .foregroundStyle(Color.ink700)
            .padding(Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r16))
    }

    private var actions: some View {
        VStack(spacing: Spacing.s4) {
            Button {
                Task { await viewModel.confirm() }
            } label: {
                if viewModel.isRequesting {
                    ProgressView().tint(.white)
                } else {
                    Text("확인했어요")
                }
            }
            .buttonStyle(.pk(.primary))
            .disabled(viewModel.isRequesting)

            Button("나중에 설정할게요") { viewModel.skip() }
                .pkTextStyle(.headline)
                .foregroundStyle(Color.ink500)
                .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
                .disabled(viewModel.isRequesting)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s8)
        .background(Color.white)
    }
}

private struct PermissionCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let badge: LocalizedStringKey?
    let message: LocalizedStringKey
    let tint: Color
    let background: Color

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack(spacing: Spacing.s8) {
                    Text(title).pkTextStyle(.title2).foregroundStyle(Color.ink900)
                    if let badge {
                        Text(badge).pkTextStyle(.caption).foregroundStyle(Color.leaf600)
                    }
                }
                Text(message).pkTextStyle(.body).foregroundStyle(Color.ink700)
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

private struct PreviewRequester: LocationPermissionRequesting, NotificationPermissionRequesting {
    func requestWhenInUse() async {}
    func requestAuthorization() async {}
}

#Preview("기본") {
    let requester = PreviewRequester()
    PermissionGuideView(viewModel: PermissionGuideViewModel(location: requester, notification: requester, onFinished: {}))
}

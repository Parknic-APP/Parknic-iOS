import SwiftUI

/// 네트워크가 끊겼을 때 화면 위에 잠깐 보이는 한 줄 안내(아이콘 + 짧은 문장). 화면 조작을 막지 않는다.
struct OfflineBanner: View {
    var body: some View {
        Label("인터넷 연결이 불안정해요", systemImage: "wifi.slash")
            .pkTextStyle(.callout)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.s16)
            .frame(minHeight: TouchTarget.minimum)
            .background(Color.ink900, in: Capsule())
            .pkShadow(.soft2)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    /// 연결이 끊긴 동안 상단에 안내를 겹쳐 보여준다.
    func offlineNotice(isVisible: Bool) -> some View {
        overlay(alignment: .top) {
            if isVisible {
                OfflineBanner()
                    .padding(.top, Spacing.s8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}

#Preview {
    Color.canvas.ignoresSafeArea().offlineNotice(isVisible: true)
}

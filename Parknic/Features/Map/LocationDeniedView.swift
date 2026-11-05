import SwiftUI

/// 10c — 위치 권한이 꺼져 있을 때의 안내. 설정 앱으로 보내 "앱을 사용하는 동안"을 켜게 한다.
struct LocationDeniedView: View {
    let onOpenSettings: () -> Void
    let onBrowse: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s20) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                Circle().fill(Color.leaf50).frame(width: 160, height: 160)
                    .overlay(PKIllustration(assetName: "character-sad", fallbackSymbol: "pawprint.fill", size: 110))
                Image(systemName: "location.slash")
                    .foregroundStyle(Color.danger600)
                    .frame(width: 48, height: 48)
                    .background(Color.danger100, in: Circle())
            }
            .accessibilityHidden(true)
            VStack(spacing: Spacing.s8) {
                Text("위치 권한이 꺼져 있어요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text("공원 안에 머무는지 확인하려면 위치 권한이 필요해요.\n권한 없이도 지도와 리뷰는 볼 수 있어요.")
                    .pkTextStyle(.body).foregroundStyle(Color.ink500).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: Spacing.s12) {
                step(1, "설정 앱에서 파크닉 열기")
                step(2, "위치에서 '앱을 사용하는 동안' 선택")
                step(3, "정확한 위치 켜기")
            }
            .padding(Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r24))
            Spacer()
            VStack(spacing: Spacing.s8) {
                Button("설정으로 이동", action: onOpenSettings).buttonStyle(.pk(.primary))
                Button("둘러보기만 할게요", action: onBrowse).buttonStyle(.pk(.tonal))
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.s12) {
            Text("\(number)")
                .pkTextStyle(.callout).foregroundStyle(Color.leaf600)
                .frame(width: 28, height: 28).background(Color.white, in: Circle())
            Text(text).pkTextStyle(.headline).foregroundStyle(Color.ink900)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LocationDeniedView(onOpenSettings: {}, onBrowse: {})
}

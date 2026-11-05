import SwiftUI

/// 05c — 체크인을 그만둘지 묻는 확인창. 지금까지 머문 시간은 저장되지 않는다.
struct CheckInCancelDialog: View {
    let stayedMinutes: Int
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.ink900.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onContinue)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.s12) {
                PKIllustration(assetName: "character-sad", fallbackSymbol: "pawprint.fill", size: 72)
                Text("체크인을 그만둘까요?").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                Text(message)
                    .pkTextStyle(.body)
                    .foregroundStyle(Color.ink500)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.s8)
                Button("계속 머무르기", action: onContinue).buttonStyle(.pk(.primary))
                Button("그만두기", action: onCancel)
                    .pkTextStyle(.headline)
                    .foregroundStyle(Color.danger600)
                    .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
            }
            .padding(Spacing.s20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r30))
            .padding(.horizontal, Spacing.s28)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var message: LocalizedStringKey {
        stayedMinutes > 0
            ? "지금까지 머문 \(stayedMinutes)분은 저장되지 않아요.\n20분을 채워야 배지를 받을 수 있어요."
            : "지금까지 머문 시간은 저장되지 않아요.\n20분을 채워야 배지를 받을 수 있어요."
    }
}

#Preview("7분 머묾") {
    CheckInCancelDialog(stayedMinutes: 7, onContinue: {}, onCancel: {})
}

#Preview("1분 미만") {
    CheckInCancelDialog(stayedMinutes: 0, onContinue: {}, onCancel: {})
}

import SwiftUI

/// 온보딩 진행 표시(3단계). 색만이 아니라 접근성 값으로도 단계를 알려준다.
struct OnboardingProgress: View {
    let step: Int
    var total = 3

    var body: some View {
        HStack(spacing: Spacing.s8) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.leaf500 : Color.ink100)
                    .frame(width: 44, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행 단계")
        .accessibilityValue("\(step) / \(total)")
    }
}

#Preview {
    VStack(spacing: Spacing.s16) {
        OnboardingProgress(step: 1)
        OnboardingProgress(step: 2)
        OnboardingProgress(step: 3)
    }
    .padding()
}

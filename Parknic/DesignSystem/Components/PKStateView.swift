import SwiftUI

// 모든 화면이 쓰는 로딩 / 빈 상태 / 에러(재시도) 공통 뷰. 화면 10a, 10b 기준.
// 일러스트는 Asset Catalog 이름으로만 참조한다(최종 에셋으로 교체해도 코드는 그대로).
// 에셋이 없는 동안은 SF Symbol로 대체한다.

struct PKIllustration: View {
    /// Asset Catalog 이미지 이름. nil이거나 에셋이 없으면 `fallbackSymbol`을 쓴다.
    var assetName: String?
    var fallbackSymbol: String
    var size: CGFloat = 140

    var body: some View {
        Group {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName).resizable().scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .resizable().scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(Color.leaf600)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 10a — 로딩
struct PKLoadingView: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey?

    var body: some View {
        VStack(spacing: Spacing.s16) {
            PKIllustration(assetName: "character-default", fallbackSymbol: "pawprint.fill")
            ProgressView().tint(.leaf600)
            VStack(spacing: Spacing.s8) {
                Text(title).pkTextStyle(.title2).foregroundStyle(Color.ink900)
                if let message {
                    Text(message).pkTextStyle(.body).foregroundStyle(Color.ink500)
                }
            }
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.s28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.leaf50)
        .accessibilityElement(children: .combine)
    }
}

/// 빈 상태 — 액션은 선택
struct PKEmptyView: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey?
    var assetName: String?
    var symbol = "leaf"
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        PKStateLayout(
            title: title, message: message, assetName: assetName, symbol: symbol,
            actionTitle: actionTitle, action: action)
    }
}

/// 10b — 에러, 항상 재시도 버튼을 가진다.
struct PKErrorView: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey?
    var assetName: String?
    var symbol = "wifi.slash"
    var retryTitle: LocalizedStringKey
    var onRetry: () -> Void

    var body: some View {
        PKStateLayout(
            title: title, message: message, assetName: assetName, symbol: symbol,
            actionTitle: retryTitle, actionSymbol: "arrow.clockwise", action: onRetry)
    }
}

private struct PKStateLayout: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey?
    var assetName: String?
    var symbol: String
    var actionTitle: LocalizedStringKey?
    var actionSymbol: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.s20) {
            Spacer()
            PKIllustration(assetName: assetName, fallbackSymbol: symbol)
            VStack(spacing: Spacing.s8) {
                Text(title).pkTextStyle(.title1).foregroundStyle(Color.ink900)
                if let message {
                    Text(message).pkTextStyle(.body).foregroundStyle(Color.ink500)
                }
            }
            .multilineTextAlignment(.center)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: Spacing.s8) {
                        if let actionSymbol { Image(systemName: actionSymbol) }
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.pk(.primary))
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .padding(.top, Spacing.s28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
    }
}

#Preview("로딩") {
    PKLoadingView(title: "주변 공원을 찾고 있어요", message: "잠깐만요, 금방 끝나요")
}

#Preview("빈 상태") {
    PKEmptyView(title: "근처에 공원이 없어요", message: "1km 안에 도시공원이 없어요. 지도를 움직여 찾아보세요.")
}

#Preview("에러") {
    PKErrorView(
        title: "인터넷 연결이 불안정해요",
        message: "연결 상태를 확인하고 다시 시도해주세요. 체크인 중이었다면 기록은 기기에 안전하게 남아 있어요.",
        retryTitle: "다시 시도", onRetry: {})
}

import SwiftUI

/// 05d·05e — 체크인이 끊겼거나 실패했을 때의 안내
struct CheckInFailedView: View {
    let reason: CheckInFailureReason
    let parkName: String
    /// 반경 안에서 머문 시간(초). 알 수 없으면 nil
    let stayed: TimeInterval?
    let onRetry: () -> Void
    let onBackToMap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s20) {
            Spacer()
            illustration
            VStack(spacing: Spacing.s8) {
                Text(content.title).pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text(content.message).pkTextStyle(.body).foregroundStyle(Color.ink500)
            }
            .multilineTextAlignment(.center)
            summary
            Spacer()
            VStack(spacing: Spacing.s8) {
                Button(content.retryTitle, action: onRetry).buttonStyle(.pk(.primary))
                Button("지도로 돌아가기", action: onBackToMap).buttonStyle(.pk(.tonal))
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.ignoresSafeArea())
    }

    // MARK: 구성

    private var illustration: some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(Color.ink100).frame(width: 180, height: 180)
                .overlay(PKIllustration(assetName: "character-sad", fallbackSymbol: "pawprint.fill", size: 120))
            if reason == .midnight {
                Text("00:00")
                    .pkTextStyle(.headline)
                    .foregroundStyle(Color.sun300)
                    .padding(.horizontal, Spacing.s12)
                    .frame(minHeight: 36)
                    .background(Color.ink900, in: RoundedRectangle(cornerRadius: Radius.r16))
            } else {
                Image(systemName: "mappin.slash")
                    .foregroundStyle(Color.danger600)
                    .frame(width: 48, height: 48)
                    .background(Color.danger100, in: Circle())
            }
        }
        .accessibilityHidden(true)
    }

    private var summary: some View {
        VStack(spacing: 0) {
            row("공원", value: Text(parkName).foregroundStyle(Color.ink900))
            if let stayed {
                Divider()
                row("머문 시간", value: Text(DurationFormatter.minutesAndSeconds(stayed)).foregroundStyle(Color.ink900))
            }
            Divider()
            row("끊긴 이유", value: Text(content.reason).foregroundStyle(Color.danger600))
        }
        .padding(.horizontal, Spacing.s20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private func row(_ title: LocalizedStringKey, value: Text) -> some View {
        HStack {
            Text(title).pkTextStyle(.body).foregroundStyle(Color.ink500)
            Spacer()
            value.pkTextStyle(.headline)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    // MARK: 문구

    private struct Content {
        let title: LocalizedStringKey
        let message: LocalizedStringKey
        let reason: LocalizedStringKey
        let retryTitle: LocalizedStringKey
    }

    private var content: Content {
        switch reason {
        case .outOfRange:
            Content(
                title: "체크인이 끊겼어요",
                message: "공원 밖에 1분 넘게 있어서 기록이 멈췄어요. 공원 안에서 다시 시작할 수 있어요.",
                reason: "공원 이탈 1분 초과", retryTitle: "다시 체크인하기")
        case .midnight:
            Content(
                title: "자정이 지나 기록이 초기화됐어요",
                message: "배지는 하루 단위로 지급돼요. 자정을 넘긴 체크인은 오늘 날짜로 새로 시작해야 해요.",
                reason: "자정 리셋 (00:00)", retryTitle: "새로 시작하기")
        case .appTerminated:
            // 디자인에 없는 상태(재실행 복구). 같은 형식으로 문구를 맞췄다.
            Content(
                title: "체크인이 중단됐어요",
                message: "앱이 종료되어 위치를 확인할 수 없었어요. 앱을 켜 둔 채 다시 시작해 주세요.",
                reason: "앱 종료", retryTitle: "다시 체크인하기")
        }
    }
}

#Preview("공원 이탈") {
    CheckInFailedView(reason: .outOfRange, parkName: "보라매공원", stayed: 446, onRetry: {}, onBackToMap: {})
}

#Preview("자정") {
    CheckInFailedView(reason: .midnight, parkName: "보라매공원", stayed: 446, onRetry: {}, onBackToMap: {})
}

#Preview("앱 종료(머문 시간 모름)") {
    CheckInFailedView(reason: .appTerminated, parkName: "보라매공원", stayed: nil, onRetry: {}, onBackToMap: {})
}

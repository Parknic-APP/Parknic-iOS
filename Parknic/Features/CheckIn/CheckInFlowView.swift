import SwiftUI

/// 체크인 한 번의 화면 흐름. 코디네이터 상태에 맞는 화면을 고른다.
/// 시작 버튼(지도·공원 시트)은 별도 작업이며, 이 화면은 시작된 체크인을 보여준다.
struct CheckInFlowView: View {
    let coordinator: CheckInCoordinator
    let parkType: ParkType
    /// 「다시 체크인하기」 — 같은 공원에서 다시 시작한다(지도·공원 시트가 처리)
    let onRetry: () -> Void
    /// 지도로 돌아간다. 체크인은 계속 진행된다(진행 중 배너로 다시 들어온다).
    let onBackToMap: () -> Void

    @State private var isConfirmingCancel = false

    var body: some View {
        ZStack {
            content
            if isConfirmingCancel, let display {
                CheckInCancelDialog(
                    stayedMinutes: display.stayedMinutes,
                    onContinue: { isConfirmingCancel = false },
                    onCancel: {
                        isConfirmingCancel = false
                        Task { await coordinator.cancel() }
                    })
            }
        }
        .animation(.easeOut(duration: 0.15), value: isConfirmingCancel)
        // 취소가 끝나면 처음 상태로 정리하고 지도로 돌아간다.
        .onChange(of: coordinator.state) { _, state in
            if case .cancelled = state {
                coordinator.dismiss()
                onBackToMap()
            }
        }
    }

    private var display: CheckInProgressDisplay? {
        CheckInProgressDisplay.make(from: coordinator, parkType: parkType)
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.state {
        case .inProgress, .outOfRange, .completing:
            if let display {
                CheckInProgressView(
                    display: display, onRequestCancel: { isConfirmingCancel = true }, onShowMap: onBackToMap)
            }
        case .failed(let session, let reason):
            CheckInFailedView(
                reason: reason, parkName: session.parkName, stayed: coordinator.stayed,
                onRetry: {
                    coordinator.dismiss()
                    onRetry()
                },
                onBackToMap: {
                    coordinator.dismiss()
                    onBackToMap()
                })
        case .completed:
            // 배지 획득 화면(06a)은 다음 작업에서 구현한다.
            PKEmptyView(
                title: "배지를 받았어요", message: "배지 획득 화면은 준비 중이에요", actionTitle: "지도로 돌아가기",
                action: {
                    coordinator.dismiss()
                    onBackToMap()
                })
        case .idle, .cancelled:
            Color.canvas.ignoresSafeArea()
        }
    }
}

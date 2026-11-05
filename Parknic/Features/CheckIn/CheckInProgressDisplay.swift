import Foundation

/// 체크인 진행 화면(12c·05a·05b)에 보여줄 값. 코디네이터 상태에서 만들어 화면이 계산하지 않게 한다.
struct CheckInProgressDisplay: Equatable {
    enum Phase: Equatable {
        /// 공원 안에서 타이머가 흐르는 중
        case inside
        /// 반경 밖. 타이머가 멈추고 `graceRemaining` 안에 돌아와야 한다.
        case outOfRange(metersOutside: Int, graceRemaining: TimeInterval)
        /// 20분을 채워 서버가 배지를 확인하는 중
        case completing
    }

    let parkName: String
    let parkType: ParkType
    let remaining: TimeInterval
    let stayed: TimeInterval
    let phase: Phase

    static let totalDuration = CheckInTracker.requiredDuration

    /// 0(시작) ~ 1(완료). 원형 진행 표시의 길이.
    var progress: Double {
        min(1, max(0, 1 - remaining / Self.totalDuration))
    }

    var stayedMinutes: Int { DurationFormatter.wholeMinutes(stayed) }

    /// 진행 중이 아니면 nil
    @MainActor
    static func make(from coordinator: CheckInCoordinator, parkType: ParkType) -> CheckInProgressDisplay? {
        guard let session = coordinator.state.session, coordinator.state.isActive else { return nil }
        let phase: Phase
        switch coordinator.state {
        case .outOfRange:
            let info = coordinator.outOfRange
            phase = .outOfRange(
                metersOutside: Int((info?.metersOutside ?? 0).rounded()), graceRemaining: info?.graceRemaining ?? 0)
        case .completing:
            phase = .completing
        default:
            phase = .inside
        }
        return CheckInProgressDisplay(
            parkName: session.parkName, parkType: parkType, remaining: coordinator.remaining ?? 0,
            stayed: coordinator.stayed ?? 0, phase: phase)
    }
}

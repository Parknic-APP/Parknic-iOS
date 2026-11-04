import Foundation

/// 진행 중인 체크인 세션. `startedAt`은 서버가 준 시작 시각이다.
struct CheckInSession: Equatable, Codable, Sendable {
    let id: Int
    let parkID: Int
    let parkName: String
    let center: Coordinate
    /// 공원 판정 반경(m). 서버가 면적 기반으로 계산해 내려준다.
    let radiusM: Double
    let startedAt: Date
}

/// 서버 `fail` API의 `reason` 값과 같다.
enum CheckInFailureReason: String, Equatable, Codable, Sendable {
    case outOfRange = "OUT_OF_RANGE"
    case midnight = "MIDNIGHT"
    case appTerminated = "APP_TERMINATED"
}

/// 위치 한 건. 시간 판정은 `now`로 하므로 시각은 담지 않는다.
struct LocationSample: Equatable, Sendable {
    var coordinate: Coordinate
    /// 수평 정확도(m). 음수면 유효하지 않은 값이다.
    var horizontalAccuracy: Double
}

enum CheckInState: Equatable, Sendable {
    case idle
    case inProgress(CheckInSession)
    /// 반경을 벗어났다. `since`부터 1분 안에 돌아오면 이어서 한다.
    case outOfRange(CheckInSession, since: Date)
    /// 20분을 채워 서버에 완료를 요청했고 응답을 기다린다.
    case completing(CheckInSession)
    case completed(CheckInSession)
    case failed(CheckInSession, CheckInFailureReason)
    case cancelled(CheckInSession)

    /// 측정이 필요한 상태
    var isActive: Bool {
        switch self {
        case .inProgress, .outOfRange, .completing: true
        case .idle, .completed, .failed, .cancelled: false
        }
    }

    var session: CheckInSession? {
        switch self {
        case .idle: nil
        case .inProgress(let s), .outOfRange(let s, _), .completing(let s), .completed(let s),
            .failed(let s, _), .cancelled(let s):
            s
        }
    }
}

/// 트래커가 바깥에 시키는 일. 알림·API 호출은 바깥(드라이버)이 한다.
enum CheckInEffect: Equatable, Sendable {
    /// 즉시 경고 로컬 알림 "1분 안에 공원으로 돌아오세요"
    case warnOutOfRange
    /// 복귀했으니 경고 알림을 거둔다
    case clearOutOfRangeWarning
    /// `complete` API 요청. 좌표는 마지막으로 확인된 위치(시작·완료 시점 좌표만 서버로 보낸다).
    case requestComplete(CheckInSession, at: Coordinate?)
    case requestFail(CheckInSession, CheckInFailureReason)
    case requestCancel(CheckInSession)
}

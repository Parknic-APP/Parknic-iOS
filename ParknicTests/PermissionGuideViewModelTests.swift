import XCTest
@testable import Parknic

/// 호출 순서를 기록하는 가짜 권한 요청
@MainActor
final class StubPermissions: LocationPermissionRequesting, NotificationPermissionRequesting, @unchecked Sendable {
    private(set) var calls: [String] = []
    var locationDelay: Duration = .zero

    func requestWhenInUse() async {
        calls.append("location-start")
        try? await Task.sleep(for: locationDelay)
        calls.append("location-end")
    }

    func requestAuthorization() async {
        calls.append("notification")
    }
}

@MainActor
final class PermissionGuideViewModelTests: XCTestCase {
    func test_확인하면_위치_다음_알림_순서로_요청하고_끝낸다() async {
        let permissions = StubPermissions()
        var finished = 0
        let model = PermissionGuideViewModel(location: permissions, notification: permissions) { finished += 1 }

        await model.confirm()

        XCTAssertEqual(permissions.calls, ["location-start", "location-end", "notification"])
        XCTAssertEqual(finished, 1)
        XCTAssertFalse(model.isRequesting)
    }

    func test_나중에_설정하면_권한_창을_띄우지_않고_끝낸다() {
        let permissions = StubPermissions()
        var finished = 0
        let model = PermissionGuideViewModel(location: permissions, notification: permissions) { finished += 1 }

        model.skip()

        XCTAssertTrue(permissions.calls.isEmpty)
        XCTAssertEqual(finished, 1)
    }

    func test_요청_중에는_중복_호출과_건너뛰기를_무시한다() async {
        let permissions = StubPermissions()
        permissions.locationDelay = .milliseconds(100)
        var finished = 0
        let model = PermissionGuideViewModel(location: permissions, notification: permissions) { finished += 1 }

        let first = Task { await model.confirm() }
        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(model.isRequesting)
        await model.confirm()
        model.skip()
        await first.value

        XCTAssertEqual(permissions.calls.filter { $0 == "notification" }.count, 1)
        XCTAssertEqual(finished, 1)
    }
}

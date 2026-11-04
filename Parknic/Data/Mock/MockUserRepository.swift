import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체. `takenNicknames`에 있는 이름은 중복이다.
struct MockUserRepository: UserRepository {
    var takenNicknames: Set<String> = ["두부산책", "초록발", "오리걸음"]
    var delay: Duration = .milliseconds(300)

    func checkNickname(_ nickname: String) async throws -> Bool {
        try await Task.sleep(for: delay)
        return !takenNicknames.contains(nickname)
    }
}

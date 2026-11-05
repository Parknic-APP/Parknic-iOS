protocol ReviewRepository: Sendable {
    /// 최신순 목록. `cursor`가 nil이면 첫 페이지. 차단한 유저의 리뷰는 서버가 제외한다.
    func list(parkID: Int, cursor: String?) async throws -> ReviewPage
    func create(parkID: Int, rating: Int, content: String) async throws
    func update(reviewID: Int, rating: Int, content: String) async throws
    func delete(reviewID: Int) async throws
    func report(reviewID: Int, reason: ReportReason) async throws
    func blockUser(userID: Int) async throws
}

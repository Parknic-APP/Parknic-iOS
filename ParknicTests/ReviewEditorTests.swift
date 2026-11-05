import XCTest
@testable import Parknic

private final class RecordingReviewRepository: ReviewRepository, @unchecked Sendable {
    enum Call: Equatable {
        case create(Int, Int, String)
        case update(Int, Int, String)
        case delete(Int)
    }
    private let lock = NSLock()
    private var _calls: [Call] = []
    var error: APIError?
    var calls: [Call] { lock.withLock { _calls } }

    func list(parkID: Int, cursor: String?) async throws -> ReviewPage { ReviewPage(reviews: [], nextCursor: nil) }
    func create(parkID: Int, rating: Int, content: String) async throws {
        if let error { throw error }
        lock.withLock { _calls.append(.create(parkID, rating, content)) }
    }
    func update(reviewID: Int, rating: Int, content: String) async throws {
        if let error { throw error }
        lock.withLock { _calls.append(.update(reviewID, rating, content)) }
    }
    func delete(reviewID: Int) async throws {
        if let error { throw error }
        lock.withLock { _calls.append(.delete(reviewID)) }
    }
    func report(reviewID: Int, reason: ReportReason) async throws {}
    func blockUser(userID: Int) async throws {}
}

@MainActor
final class ReviewEditorViewModelTests: XCTestCase {
    private let longText = "호수 둘레길이 평평해서 걷기 좋아요"
    private var results: [ReviewEditorViewModel.Result] = []
    private let existing = Review(id: 9, userID: 1, nickname: "나뭇잎", characterID: 1, badgeCount: 4, rating: 4, content: "그늘이 많아서 산책하기 좋아요", createdAt: Date(), isMine: true)

    private func make(_ mode: ReviewEditorViewModel.Mode, _ repository: RecordingReviewRepository) -> ReviewEditorViewModel {
        results = []
        return ReviewEditorViewModel(mode: mode, repository: repository) { [self] in results.append($0) }
    }

    func test_처음에는_등록할_수_없다() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.rating, 0)
    }

    func test_별점과_10자_이상이_있어야_등록할_수_있다() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        model.rating = 4
        XCTAssertFalse(model.canSubmit, "내용이 없다")
        model.content = "짧아요"
        XCTAssertFalse(model.canSubmit)
        model.content = longText
        XCTAssertTrue(model.canSubmit)
        model.rating = 0
        XCTAssertFalse(model.canSubmit, "별점이 없다")
    }

    func test_공백만_10자_채워도_등록할_수_없다() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        model.rating = 5
        model.content = "           "
        XCTAssertFalse(model.isContentLongEnough)
        XCTAssertFalse(model.canSubmit)
    }

    func test_정확히_10자는_등록할_수_있다() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        model.rating = 5
        model.content = "열글자가정확히됩니다"
        XCTAssertEqual(model.content.count, 10)
        XCTAssertTrue(model.canSubmit)
        model.content = "아홉글자가딱입니다"
        XCTAssertEqual(model.content.count, 9)
        XCTAssertFalse(model.canSubmit)
    }

    func test_300자를_넘기면_잘린다() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        model.content = String(repeating: "가", count: 350)
        XCTAssertEqual(model.content.count, 300)
    }

    func test_별점_문구() {
        let model = make(.create(parkID: 1), RecordingReviewRepository())
        XCTAssertEqual(model.ratingTitle, "")
        model.rating = 1; XCTAssertEqual(model.ratingTitle, "별로예요")
        model.rating = 4; XCTAssertEqual(model.ratingTitle, "좋아요")
        model.rating = 5; XCTAssertEqual(model.ratingTitle, "최고예요")
    }

    func test_등록하면_앞뒤_공백을_뺀_내용을_보낸다() async {
        let repository = RecordingReviewRepository()
        let model = make(.create(parkID: 3), repository)
        model.rating = 5
        model.content = "  \(longText)  \n"
        await model.submit()
        XCTAssertEqual(repository.calls, [.create(3, 5, longText)])
        XCTAssertEqual(results, [.saved])
    }

    func test_등록에_실패하면_문구를_보여주고_다시_시도할_수_있다() async {
        let repository = RecordingReviewRepository()
        repository.error = .network
        let model = make(.create(parkID: 3), repository)
        model.rating = 5
        model.content = longText
        await model.submit()
        XCTAssertEqual(model.errorMessage, APIError.network.userMessage)
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(model.canSubmit)

        repository.error = nil
        await model.submit()
        XCTAssertEqual(results, [.saved])
    }

    func test_서버가_배지_없음으로_거절하면_쓸_수_없다고_알린다() async {
        let repository = RecordingReviewRepository()
        repository.error = .server(status: 403, code: "REVIEW_BADGE_REQUIRED")
        let model = make(.create(parkID: 3), repository)
        model.rating = 5
        model.content = longText
        await model.submit()
        XCTAssertEqual(results, [.notAllowed])
    }

    func test_이미_쓴_공원이면_안내_문구를_보여준다() async {
        let repository = RecordingReviewRepository()
        repository.error = .server(status: 409, code: "REVIEW_ALREADY_EXISTS")
        let model = make(.create(parkID: 3), repository)
        model.rating = 5
        model.content = longText
        await model.submit()
        XCTAssertEqual(model.errorMessage, "이미 이 공원에 리뷰를 썼어요")
    }

    func test_수정_화면은_기존_값으로_채워진다() {
        let model = make(.edit(existing), RecordingReviewRepository())
        XCTAssertEqual(model.rating, 4)
        XCTAssertEqual(model.content, existing.content)
        XCTAssertTrue(model.isEditing)
    }

    func test_바뀐_것이_없으면_수정할_수_없다() {
        let model = make(.edit(existing), RecordingReviewRepository())
        XCTAssertFalse(model.canSubmit)
        model.rating = 5
        XCTAssertTrue(model.canSubmit)
        model.rating = 4
        XCTAssertFalse(model.canSubmit, "원래대로 되돌리면 다시 막힌다")
        model.content = existing.content + " 정말로"
        XCTAssertTrue(model.canSubmit)
    }

    func test_수정하면_리뷰_번호로_보낸다() async {
        let repository = RecordingReviewRepository()
        let model = make(.edit(existing), repository)
        model.rating = 5
        await model.submit()
        XCTAssertEqual(repository.calls, [.update(9, 5, existing.content)])
        XCTAssertEqual(results, [.saved])
    }

    func test_삭제하면_서버에_알리고_끝낸다() async {
        let repository = RecordingReviewRepository()
        let model = make(.edit(existing), repository)
        await model.delete()
        XCTAssertEqual(repository.calls, [.delete(9)])
        XCTAssertEqual(results, [.deleted])
    }

    func test_삭제에_실패하면_문구를_보여주고_끝내지_않는다() async {
        let repository = RecordingReviewRepository()
        repository.error = .network
        let model = make(.edit(existing), repository)
        await model.delete()
        XCTAssertEqual(model.errorMessage, APIError.network.userMessage)
        XCTAssertTrue(results.isEmpty)
    }

    func test_새_리뷰_작성_화면에서는_삭제할_수_없다() async {
        let repository = RecordingReviewRepository()
        let model = make(.create(parkID: 1), repository)
        await model.delete()
        XCTAssertTrue(repository.calls.isEmpty)
        XCTAssertFalse(model.isEditing)
    }
}

final class MockReviewRepositoryTests: XCTestCase {
    func test_이미_쓴_리뷰가_있으면_다시_쓸_수_없다() async {
        let repository = MockReviewRepository(delay: .zero)
        do {
            try await repository.create(parkID: 1, rating: 5, content: "이미 쓴 리뷰가 있는 상태입니다")
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual((error as? APIError)?.serverCode, .reviewAlreadyExists)
        }
    }

    func test_삭제한_뒤에는_다시_쓸_수_있고_목록에_나타난다() async throws {
        let repository = MockReviewRepository(delay: .zero)
        try await repository.delete(reviewID: 3)
        try await repository.create(parkID: 1, rating: 4, content: "삭제하고 다시 쓴 리뷰입니다")
        let page = try await repository.list(parkID: 1, cursor: nil)
        XCTAssertEqual(page.reviews.filter(\.isMine).count, 1)
        XCTAssertEqual(page.reviews.first(where: \.isMine)?.rating, 4)
    }

    func test_차단한_유저의_리뷰는_목록에서_빠진다() async throws {
        let repository = MockReviewRepository(delay: .zero)
        try await repository.blockUser(userID: 7)
        let page = try await repository.list(parkID: 1, cursor: nil)
        XCTAssertFalse(page.reviews.contains { $0.userID == 7 })
    }

    func test_페이지_크기로_나누어_돌려준다() async throws {
        let repository = MockReviewRepository(delay: .zero, pageSize: 2)
        let first = try await repository.list(parkID: 1, cursor: nil)
        XCTAssertEqual(first.reviews.count, 2)
        XCTAssertNotNil(first.nextCursor)
        let second = try await repository.list(parkID: 1, cursor: first.nextCursor)
        XCTAssertEqual(second.reviews.count, 2)
        XCTAssertNil(second.nextCursor)
    }
}

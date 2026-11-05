import Observation

/// 리뷰 작성·수정(08e·08f). 별점 + 텍스트만 쓴다(키워드 태그는 1차 제외).
@MainActor @Observable
final class ReviewEditorViewModel {
    enum Mode: Equatable {
        case create(parkID: Int)
        case edit(Review)
    }

    enum Result: Equatable {
        case saved
        case deleted
        /// 배지가 없어 쓸 수 없다(서버 판정)
        case notAllowed
    }

    static let contentRange = 10...300
    static let ratingTitles = ["", "별로예요", "아쉬워요", "보통이에요", "좋아요", "최고예요"]

    let mode: Mode
    var rating: Int
    var content: String {
        didSet {
            if content.count > Self.contentRange.upperBound { content = String(content.prefix(Self.contentRange.upperBound)) }
        }
    }
    private(set) var isWorking = false
    /// 서버·네트워크 오류 문구
    private(set) var errorMessage: String?

    private let repository: ReviewRepository
    private let onFinished: (Result) -> Void

    init(mode: Mode, repository: ReviewRepository, onFinished: @escaping (Result) -> Void) {
        self.mode = mode
        self.repository = repository
        self.onFinished = onFinished
        switch mode {
        case .create:
            rating = 0
            content = ""
        case .edit(let review):
            rating = review.rating
            content = review.content
        }
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var trimmedContent: String { content.trimmingCharacters(in: .whitespacesAndNewlines) }

    var ratingTitle: String { Self.ratingTitles.indices.contains(rating) ? Self.ratingTitles[rating] : "" }

    var isContentLongEnough: Bool { trimmedContent.count >= Self.contentRange.lowerBound }

    /// 수정할 때는 바뀐 것이 있어야 저장할 수 있다.
    private var hasChanges: Bool {
        guard case .edit(let review) = mode else { return true }
        return review.rating != rating || review.content != trimmedContent
    }

    var canSubmit: Bool {
        !isWorking && (1...5).contains(rating) && isContentLongEnough && hasChanges
    }

    func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            switch mode {
            case .create(let parkID):
                try await repository.create(parkID: parkID, rating: rating, content: trimmedContent)
            case .edit(let review):
                try await repository.update(reviewID: review.id, rating: rating, content: trimmedContent)
            }
            onFinished(.saved)
        } catch let error as APIError {
            if error.serverCode == .reviewBadgeRequired {
                onFinished(.notAllowed)
            } else {
                errorMessage = error.userMessage
            }
        } catch {
            errorMessage = APIError.network.userMessage
        }
    }

    /// 내 리뷰 삭제(확인 후에 부른다)
    func delete() async {
        guard case .edit(let review) = mode, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await repository.delete(reviewID: review.id)
            onFinished(.deleted)
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? APIError.network.userMessage
        }
    }
}

import SwiftUI

/// 온보딩 흐름: 닉네임 → 캐릭터 → 권한 안내. 캐릭터·권한 단계는 다음 작업에서 구현한다.
struct OnboardingView: View {
    let makeNicknameViewModel: () -> NicknameViewModel
    @State private var nicknameViewModel: NicknameViewModel
    @State private var path: [Step] = []

    enum Step: Hashable {
        case character(nickname: String)
    }

    init(makeNicknameViewModel: @escaping () -> NicknameViewModel) {
        self.makeNicknameViewModel = makeNicknameViewModel
        _nicknameViewModel = State(initialValue: makeNicknameViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                OnboardingProgress(step: 1).padding(.top, Spacing.s16)
                NicknameView(viewModel: nicknameViewModel) { nickname in
                    path.append(.character(nickname: nickname))
                }
            }
            .background(Color.white)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .character:
                    PKEmptyView(title: "캐릭터 선택", message: "준비 중이에요")
                }
            }
        }
    }
}

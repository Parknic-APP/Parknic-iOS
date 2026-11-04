import SwiftUI

// 버튼 스타일: Primary(체크인), Accent(랭킹 보기), Tonal, Secondary, Destructive
// Disabled는 SwiftUI의 `.disabled(true)`로 표현한다.
// 흰 글자는 leaf600 위에서만 쓴다. sun500 위의 글자는 ink900.

enum PKButtonKind {
    case primary, accent, tonal, secondary, destructive
}

enum PKButtonSize {
    /// 높이 36, 터치 영역은 44pt로 확장한다.
    case small
    /// 높이 44
    case medium
    /// 화면 하단 주요 버튼
    case large

    var height: CGFloat {
        switch self {
        case .small: 36
        case .medium: 44
        case .large: 56
        }
    }
}

struct PKButtonStyle: ButtonStyle {
    var kind: PKButtonKind = .primary
    var size: PKButtonSize = .large
    var fillsWidth = true

    @Environment(\.isEnabled) private var isEnabled

    private static let thickness: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        // 누르면 하단 두께가 사라지고 버튼이 그만큼 내려앉는다.
        let depth = isEnabled && kind.hasDepth && !pressed ? Self.thickness : 0

        configuration.label
            .pkTextStyle(size == .small ? .callout : .headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: size.height)
            .padding(.horizontal, Spacing.s20)
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Radius.r20)
                    .fill(depthColor)
                    .offset(y: depth)
            }
            .background(background, in: RoundedRectangle(cornerRadius: Radius.r20))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Radius.r20)
                        .stroke(isEnabled ? Color.ink300 : Color.ink100, lineWidth: 1.5)
                }
            }
            .padding(.bottom, depth)
            .frame(minHeight: TouchTarget.minimum)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }

    private var foreground: Color {
        guard isEnabled else { return .ink500 }
        switch kind {
        case .primary: return .white
        case .accent: return .ink900
        case .tonal: return .leaf600
        case .secondary: return .ink900
        case .destructive: return .danger600
        }
    }

    private var background: Color {
        guard isEnabled else { return kind == .secondary ? .white : .ink100 }
        switch kind {
        case .primary: return .leaf600
        case .accent: return .sun500
        case .tonal: return .leaf100
        case .secondary: return .white
        case .destructive: return .danger100
        }
    }

    private var depthColor: Color {
        switch kind {
        case .primary: .leaf900
        case .accent: .sun700
        default: .clear
        }
    }
}

private extension PKButtonKind {
    var hasDepth: Bool { self == .primary || self == .accent }
}

extension ButtonStyle where Self == PKButtonStyle {
    static func pk(_ kind: PKButtonKind = .primary, size: PKButtonSize = .large, fillsWidth: Bool = true) -> PKButtonStyle {
        PKButtonStyle(kind: kind, size: size, fillsWidth: fillsWidth)
    }
}

#Preview("종류") {
    VStack(spacing: Spacing.s16) {
        Button("여기서 체크인하기") {}.buttonStyle(.pk(.primary))
        Button("랭킹 보기") {}.buttonStyle(.pk(.accent))
        Button("리뷰 쓰기") {}.buttonStyle(.pk(.tonal))
        Button("취소") {}.buttonStyle(.pk(.secondary))
        Button("탈퇴하기") {}.buttonStyle(.pk(.destructive))
    }
    .padding(Spacing.s16)
    .background(Color.canvas)
}

#Preview("비활성·크기") {
    VStack(spacing: Spacing.s16) {
        Button("공원 안에서 체크인할 수 있어요") {}.buttonStyle(.pk(.primary)).disabled(true)
        Button("취소") {}.buttonStyle(.pk(.secondary)).disabled(true)
        Button("중간") {}.buttonStyle(.pk(.primary, size: .medium))
        Button("작게") {}.buttonStyle(.pk(.tonal, size: .small, fillsWidth: false))
    }
    .padding(Spacing.s16)
    .background(Color.canvas)
}

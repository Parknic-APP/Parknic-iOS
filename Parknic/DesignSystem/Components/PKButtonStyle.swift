import SwiftUI

// 버튼 스타일: Primary(체크인), Accent(랭킹 보기), Tonal, Secondary, Destructive
// Disabled는 SwiftUI의 `.disabled(true)`로 표현한다.
// 흰 글자는 leaf600 위에서만 쓴다. sun500 위의 글자는 ink900.

enum PKButtonKind {
    case primary, accent, tonal, secondary, destructive
}

enum PKButtonSize {
    /// 높이 40, 터치 영역은 44pt로 확장한다.
    case small
    /// 높이 48
    case medium
    /// 화면 하단 주요 버튼
    case large

    var height: CGFloat {
        switch self {
        case .small: 40
        case .medium: 48
        case .large: 58
        }
    }

    /// 모서리 반경. 높이의 절반에 가깝게 둥글려 말랑한 알약 모양으로 만든다.
    var cornerRadius: CGFloat { height * 0.46 }

    /// 버튼 글씨. 크기에 따라 키워서 어디서든 또렷하게 읽히게 한다.
    var textStyle: PKTextStyle {
        switch self {
        case .small: .buttonSmall
        case .medium: .buttonMedium
        case .large: .buttonLarge
        }
    }
}

/// 버튼 한 벌의 색. 종류별 색과 브랜드 색(로그인 버튼)이 같은 모양 틀을 쓰도록 값만 따로 둔다.
struct PKButtonPalette {
    var foreground: Color
    var background: Color
    /// 아래로 튀어나온 두께 색
    var depth: Color
    /// 테두리(없으면 nil)
    var border: Color?

    static let primary = PKButtonPalette(foreground: .white, background: .leaf600, depth: .leaf900)
    static let accent = PKButtonPalette(foreground: .ink900, background: .sun500, depth: .sun700)
    static let tonal = PKButtonPalette(foreground: .leaf600, background: .leaf100, depth: .leaf300)
    static let secondary = PKButtonPalette(foreground: .ink900, background: .white, depth: .ink300, border: .ink300)
    static let destructive = PKButtonPalette(
        foreground: .danger600, background: .danger100, depth: Color.danger600.opacity(0.45))
    /// 쓸 수 없을 때. 두께는 남겨 두어 다른 버튼과 같은 모양으로 보이게 한다.
    static let disabled = PKButtonPalette(foreground: .ink500, background: .ink100, depth: .ink300)

    init(foreground: Color, background: Color, depth: Color, border: Color? = nil) {
        self.foreground = foreground
        self.background = background
        self.depth = depth
        self.border = border
    }

    init(kind: PKButtonKind) {
        switch kind {
        case .primary: self = .primary
        case .accent: self = .accent
        case .tonal: self = .tonal
        case .secondary: self = .secondary
        case .destructive: self = .destructive
        }
    }
}

/// 모든 버튼이 같은 모양(알약 + 아래 두께 그림자, 누르면 눌렸다 튀어 오름)을 쓰는 공통 틀
private struct PKButtonChrome: ViewModifier {
    let palette: PKButtonPalette
    let size: PKButtonSize
    let fillsWidth: Bool
    let pressed: Bool

    static let thickness: CGFloat = 4

    func body(content: Content) -> some View {
        // 누르면 하단 두께가 사라지고 버튼이 그만큼 내려앉는다.
        let depth = pressed ? 0 : Self.thickness
        content
            .pkTextStyle(size.textStyle)
            .foregroundStyle(palette.foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: size.height)
            .padding(.horizontal, Spacing.s20)
            .background(palette.background, in: RoundedRectangle(cornerRadius: size.cornerRadius))
            // 하단 두께는 면 뒤에 깔아 아래로 튀어나온 부분만 보이게 한다.
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(palette.depth)
                    .offset(y: depth)
            }
            .overlay {
                if let border = palette.border {
                    RoundedRectangle(cornerRadius: size.cornerRadius).stroke(border, lineWidth: 1.5)
                }
            }
            .padding(.bottom, depth)
            .frame(minHeight: TouchTarget.minimum)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.96 : 1)
            // 누를 때 살짝 눌렸다가 말랑하게 튀어 오른다.
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pressed)
    }
}

struct PKButtonStyle: ButtonStyle {
    var kind: PKButtonKind = .primary
    var size: PKButtonSize = .large
    var fillsWidth = true

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(
            PKButtonChrome(
                palette: isEnabled ? PKButtonPalette(kind: kind) : .disabled, size: size, fillsWidth: fillsWidth,
                pressed: configuration.isPressed && isEnabled))
    }
}

/// 브랜드 색 버튼(Apple·카카오·Google 로그인). 모양은 다른 버튼과 같다.
struct PKBrandButtonStyle: ButtonStyle {
    let palette: PKButtonPalette
    var size: PKButtonSize = .large

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(
            PKButtonChrome(
                palette: isEnabled ? palette : .disabled, size: size, fillsWidth: true,
                pressed: configuration.isPressed && isEnabled))
    }
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

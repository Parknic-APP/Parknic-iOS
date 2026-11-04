import SwiftUI

// 파크닉 디자인 시스템 v1 — 간격·모서리·그림자

/// 간격. s16은 화면 좌우 여백, s20은 시트 내부 여백·섹션 간격.
enum Spacing {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s28: CGFloat = 28
    static let s40: CGFloat = 40
}

/// 모서리 반경. r8 태그 · r16 마커 · r20 버튼 · r24 카드 · r30 시트
enum Radius {
    static let r8: CGFloat = 8
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let r30: CGFloat = 30
    static let pill: CGFloat = 99
}

/// 터치 영역 최소 크기(pt)
enum TouchTarget {
    static let minimum: CGFloat = 44
}

/// 그림자. 디자인의 CSS blur 값은 SwiftUI radius의 약 2배다.
struct PKShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension PKShadow {
    /// 0 2px 8px rgba(22,61,40,.08)
    static let soft1 = PKShadow(color: Color.leaf900.opacity(0.08), radius: 4, x: 0, y: 2)
    /// 0 8px 24px rgba(22,61,40,.16)
    static let soft2 = PKShadow(color: Color.leaf900.opacity(0.16), radius: 12, x: 0, y: 8)
    // "통통" 버튼 그림자(안쪽 하단 4px + 초록 그림자)는 버튼 스타일에서 구현한다.
}

extension View {
    func pkShadow(_ shadow: PKShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

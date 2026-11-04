import SwiftUI

// 파크닉 디자인 시스템 v1 — 색 토큰
// 값의 출처: docs/design/design-tokens.md
// 흰 글자는 leaf600 위에서만 쓴다(대비 4.6:1). leaf500, sun500 위의 글자는 ink900.

extension Color {
    /// 0xRRGGBB 값으로 색을 만든다.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Leaf · 메인
extension Color {
    static let leaf900 = Color(hex: 0x163D28)
    static let leaf600 = Color(hex: 0x1C854B)
    static let leaf500 = Color(hex: 0x34B36B)
    static let leaf300 = Color(hex: 0x9FDDB5)
    static let leaf100 = Color(hex: 0xE2F4E8)
    static let leaf50 = Color(hex: 0xF2FAF4)
}

// MARK: - Sun · 포인트 / Danger
extension Color {
    static let sun700 = Color(hex: 0xA86400)
    static let sun500 = Color(hex: 0xFFB627)
    static let sun300 = Color(hex: 0xFFD77A)
    static let sun100 = Color(hex: 0xFFF2CF)
    static let danger600 = Color(hex: 0xC53A2F)
    static let danger100 = Color(hex: 0xFDE8E5)
}

// MARK: - Ink · 뉴트럴 (살짝 초록기)
extension Color {
    static let ink900 = Color(hex: 0x1E2420)
    static let ink700 = Color(hex: 0x3D4741)
    static let ink500 = Color(hex: 0x6B766F)
    static let ink300 = Color(hex: 0xC3CCC6)
    static let ink100 = Color(hex: 0xEEF2EF)
    /// 화면 배경
    static let canvas = Color(hex: 0xF7F8F3)
}

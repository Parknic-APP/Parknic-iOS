import SwiftUI

// 공원 유형별 배지·태그 색. 값의 출처: docs/design/design-tokens.md
extension ParkType {
    /// 배지·태그의 기본색
    var color: Color {
        switch self {
        case .neighborhood: Color(hex: 0x34B36B)
        case .children: Color(hex: 0xFFB627)
        case .small: Color(hex: 0xF58BA6)
        case .sports: Color(hex: 0x5C7CF0)
        case .waterfront: Color(hex: 0x4FB3E8)
        case .culture: Color(hex: 0xA57FE6)
        case .history: Color(hex: 0xC9824F)
        }
    }

    /// 배지 테두리·아이콘 등에 쓰는 진한 색
    var darkColor: Color {
        switch self {
        case .neighborhood: Color(hex: 0x1C854B)
        case .children: Color(hex: 0xE08F00)
        case .small: Color(hex: 0xD9607F)
        case .sports: Color(hex: 0x3F5DD0)
        case .waterfront: Color(hex: 0x2A8FC7)
        case .culture: Color(hex: 0x8058C9)
        case .history: Color(hex: 0xA5612F)
        }
    }
}

extension ParkType {
    /// 배지 이미지 에셋 이름(최종 손그림 에셋으로 교체해도 코드는 그대로)
    var badgeAssetName: String { "badge-\(rawValue.lowercased())" }
}

import SwiftUI

// 태그: 공원 유형, "오늘", "새 업적", 순위 변동, 월 칩.
// 정보는 색만으로 구분하지 않는다 → 항상 텍스트(+선택 아이콘)를 함께 둔다.

struct PKTag: View {
    enum Style {
        /// 공원 유형 — 유형별 색 띠 아이콘 + 텍스트
        case park(ParkType)
        /// 오늘 획득, 새 업적 등 강조
        case highlight
        /// 중립 (월 칩, 순위 변동 등)
        case neutral
    }

    var text: LocalizedStringKey
    var symbol: String?
    var style: Style = .neutral

    var body: some View {
        HStack(spacing: Spacing.s4) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(text)
        }
        .pkTextStyle(.caption)
        .foregroundStyle(Color.ink900)
        .padding(.leading, isPark ? Spacing.s12 : Spacing.s8)
        .padding(.trailing, Spacing.s8)
        .frame(minHeight: 24)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.r8))
        .overlay(alignment: .leading) {
            if case .park(let type) = style {
                Capsule().fill(type.color).frame(width: 3, height: 12).padding(.leading, 3)
            }
        }
    }

    private var isPark: Bool {
        if case .park = style { true } else { false }
    }

    private var background: Color {
        switch style {
        case .park: .ink100
        case .highlight: .sun100
        case .neutral: .ink100
        }
    }
}

#Preview {
    HStack {
        PKTag(text: "오늘", symbol: "checkmark", style: .highlight)
        PKTag(text: "새 업적", symbol: "star.fill", style: .highlight)
        PKTag(text: "근린공원", style: .park(.neighborhood))
        PKTag(text: "▲1")
        PKTag(text: "2026년 11월", symbol: "calendar")
    }
    .padding()
    .background(Color.canvas)
}

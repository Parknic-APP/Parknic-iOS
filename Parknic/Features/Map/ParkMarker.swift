import SwiftUI

extension ParkType {
    /// 지도 마커·시트의 공원 유형 아이콘(최종 손그림 에셋 전 임시 심볼)
    var symbolName: String {
        switch self {
        case .neighborhood: "leaf"
        case .children: "star"
        case .small: "camera.macro"
        case .sports: "figure.run"
        case .waterfront: "drop"
        case .culture: "theatermasks"
        case .history: "building.columns"
        }
    }
}

/// 물방울 모양 핀. 위쪽은 원, 아래쪽 뾰족한 끝이 공원 위치를 가리킨다.
struct MarkerPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let circle = Path(ellipseIn: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.width))
        var tail = Path()
        let dx = radius * 0.64
        let dy = radius + radius * 0.77
        tail.move(to: CGPoint(x: rect.midX - dx, y: rect.minY + dy))
        tail.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        tail.addLine(to: CGPoint(x: rect.midX + dx, y: rect.minY + dy))
        tail.closeSubpath()
        return circle.union(tail)
    }
}

/// 마커 3상태: 미획득(흰 바탕 · 회색 아이콘) / 받은 적 있음(초록 · 누적 개수 칩) / 오늘 받음(노랑 · 체크).
/// 색 + 아이콘 + 칩으로 구분해 색만으로 정보를 전달하지 않는다.
struct ParkMarker: View {
    let park: Park
    var isSelected = false

    var body: some View {
        VStack(spacing: Spacing.s4) {
            pin
            Text(park.name)
                .pkTextStyle(.caption)
                .foregroundStyle(Color.ink900)
                .lineLimit(1)
                .padding(.horizontal, Spacing.s8)
                .frame(minHeight: 22)
                .background(Color.white, in: Capsule())
                .pkShadow(.soft1)
        }
        .scaleEffect(isSelected ? 1.15 : 1, anchor: .bottom)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var pin: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .frame(width: 44, height: 54, alignment: .top)
                .background(fill, in: MarkerPinShape())
                .overlay(MarkerPinShape().stroke(stroke, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
                .pkShadow(.soft1)
            if park.status == .earned, park.badgeCount > 0 {
                Text("\(park.badgeCount)")
                    .pkTextStyle(.caption)
                    .foregroundStyle(Color.leaf600)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.leaf600, lineWidth: 1.5))
                    .offset(x: 8, y: -8)
            }
            if park.status == .earnedToday {
                Text("오늘")
                    .pkTextStyle(.caption)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, Spacing.s8)
                    .frame(minHeight: 20)
                    .background(Color.ink900, in: Capsule())
                    .offset(x: 14, y: -12)
            }
        }
    }

    private var icon: String { park.status == .earnedToday ? "checkmark" : park.type.symbolName }

    private var fill: Color {
        switch park.status {
        case .none: .white
        case .earned: .leaf600
        case .earnedToday: .sun500
        }
    }

    private var iconColor: Color {
        switch park.status {
        case .none: .ink500
        case .earned: .white
        case .earnedToday: .ink900
        }
    }

    private var stroke: Color {
        switch park.status {
        case .none: .ink300
        case .earned: .leaf600
        case .earnedToday: .sun700
        }
    }

    private var accessibilityText: String {
        switch park.status {
        case .none: String(localized: "\(park.name), \(park.type.displayName), 아직 배지를 받지 않았어요")
        case .earned: String(localized: "\(park.name), \(park.type.displayName), 배지 \(park.badgeCount)개")
        case .earnedToday: String(localized: "\(park.name), \(park.type.displayName), 오늘 배지를 받았어요")
        }
    }
}

#Preview("3상태") {
    HStack(spacing: Spacing.s28) {
        ParkMarker(park: MockParkRepository.sample[2])
        ParkMarker(park: MockParkRepository.sample[0])
        ParkMarker(park: MockParkRepository.sample[3])
        ParkMarker(park: MockParkRepository.sample[0], isSelected: true)
    }
    .padding(Spacing.s28)
    .background(Color.leaf50)
}

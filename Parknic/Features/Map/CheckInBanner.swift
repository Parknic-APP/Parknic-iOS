import SwiftUI

/// 03b — 체크인 중 지도 상단에 보이는 진행 배너. 누르면 체크인 화면으로 돌아간다.
struct CheckInBanner: View {
    let display: CheckInProgressDisplay
    let action: () -> Void

    private var isOutOfRange: Bool {
        if case .outOfRange = display.phase { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s12) {
                ZStack {
                    Circle().stroke(Color.leaf100, lineWidth: 6)
                    Circle().trim(from: 0, to: display.progress)
                        .stroke(isOutOfRange ? Color.sun500 : Color.leaf500, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: isOutOfRange ? "pause.fill" : "pawprint.fill")
                        .font(.caption).foregroundStyle(isOutOfRange ? Color.sun700 : Color.leaf600)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text(title).pkTextStyle(.callout).foregroundStyle(isOutOfRange ? Color.danger600 : Color.ink500)
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
                        Text(DurationFormatter.clock(display.remaining)).pkTextStyle(.display).monospacedDigit()
                            .foregroundStyle(isOutOfRange ? Color.ink500 : Color.ink900)
                        Text("남음").pkTextStyle(.headline).foregroundStyle(Color.leaf600)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.ink500)
            }
            .padding(Spacing.s12)
            .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            .pkShadow(.soft2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(DurationFormatter.minutesAndSeconds(display.remaining))
        .accessibilityHint("체크인 화면으로 이동해요")
    }

    private var title: String {
        switch display.phase {
        case .inside: String(localized: "\(display.parkName)에서 쉬는 중")
        case .outOfRange: String(localized: "공원 밖이에요 · 1분 안에 돌아오세요")
        case .completing: String(localized: "배지를 확인하고 있어요")
        }
    }
}

#Preview("쉬는 중") {
    CheckInBanner(display: .init(parkName: "보라매공원", parkType: .neighborhood, remaining: 754, stayed: 446, phase: .inside), action: {})
        .padding().background(Color.leaf50)
}

#Preview("반경 밖") {
    CheckInBanner(
        display: .init(parkName: "보라매공원", parkType: .neighborhood, remaining: 754, stayed: 446, phase: .outOfRange(metersOutside: 80, graceRemaining: 42)),
        action: {}).padding().background(Color.leaf50)
}

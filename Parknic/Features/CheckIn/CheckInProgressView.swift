import SwiftUI

/// 12c·05a·05b — 체크인 진행. 일러스트는 에셋(`checkin-scene`, 캐릭터)으로 교체한다.
struct CheckInProgressView: View {
    let display: CheckInProgressDisplay
    /// 장면에 서 있는 내 캐릭터 에셋 이름. 없으면 기본 캐릭터를 쓴다.
    var characterAssetName: String?
    let onRequestCancel: () -> Void
    let onShowMap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s20) {
            topBar
            hero
            TimerRing(display: display)
            statusPill
            Spacer(minLength: 0)
            Button("체크인 그만두기", action: onRequestCancel)
                .buttonStyle(.pk(.secondary))
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.leaf50.ignoresSafeArea())
    }

    // MARK: 구성

    private var topBar: some View {
        HStack {
            // 체크인을 그만두는 버튼은 아래쪽에 있어 왼쪽 위에는 지도 버튼을 둔다.
            circleButton("map", label: "지도 보기", action: onShowMap)
            Spacer()
            VStack(spacing: Spacing.s4) {
                Text(display.parkType.displayName).pkTextStyle(.callout).foregroundStyle(Color.leaf600)
                Text(display.parkName).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            // 가운데 제목이 치우치지 않게 왼쪽 버튼과 같은 너비를 비워 둔다.
            Color.clear.frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
        }
        .padding(.top, Spacing.s8)
    }

    private func circleButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.ink900)
                .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                .background(Color.white, in: Circle())
                .pkShadow(.soft1)
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var hero: some View {
        if case .outOfRange(_, let grace) = display.phase {
            OutOfRangeBanner(graceRemaining: grace)
        } else {
            CheckInScene(display: display, characterAssetName: characterAssetName)
        }
    }

    private var statusPill: some View {
        Label {
            Text(statusText).pkTextStyle(.headline)
        } icon: {
            Image(systemName: statusSymbol)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Spacing.s16)
        .frame(minHeight: TouchTarget.minimum)
        .background(Color.white, in: Capsule())
    }

    // 색만으로 구분하지 않도록 색 + 아이콘 + 문구를 함께 쓴다.
    private var statusText: LocalizedStringKey {
        switch display.phase {
        case .inside: "공원 안에 있어요 · 앱을 닫아도 기록돼요"
        case .outOfRange(let meters, _): "공원 경계에서 \(meters)m 벗어났어요"
        case .completing: "배지를 확인하고 있어요"
        }
    }

    private var statusSymbol: String {
        switch display.phase {
        case .inside: "checkmark.circle.fill"
        case .outOfRange: "exclamationmark.circle.fill"
        case .completing: "hourglass"
        }
    }

    private var statusColor: Color {
        switch display.phase {
        case .inside, .completing: .leaf600
        case .outOfRange: .danger600
        }
    }
}

// MARK: - 타이머 링

private struct TimerRing: View {
    let display: CheckInProgressDisplay
    private let diameter: CGFloat = 248
    private let lineWidth: CGFloat = 26

    private var isPaused: Bool {
        if case .outOfRange = display.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.leaf100, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: display.progress)
                .stroke(isPaused ? Color.sun500 : Color.leaf500, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: display.progress)
            Circle().fill(Color.white).padding(lineWidth + Spacing.s8).pkShadow(.soft1)
            VStack(spacing: Spacing.s4) {
                if isPaused {
                    Label("일시정지", systemImage: "pause.fill").pkTextStyle(.callout).foregroundStyle(Color.sun700)
                } else {
                    Text("남은 시간").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                }
                Text(DurationFormatter.clock(display.remaining))
                    .pkTextStyle(.timer)
                    .foregroundStyle(isPaused ? Color.ink500 : Color.ink900)
                    .monospacedDigit()
                Text("20분 중 \(display.stayedMinutes)분 머물렀어요")
                    .pkTextStyle(.callout)
                    .foregroundStyle(Color.ink500)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPaused ? "일시정지, 남은 시간" : "남은 시간")
        .accessibilityValue(DurationFormatter.minutesAndSeconds(display.remaining))
    }
}

// MARK: - 이탈 경고

private struct OutOfRangeBanner: View {
    let graceRemaining: TimeInterval

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Label("공원 밖으로 나갔어요", systemImage: "exclamationmark.triangle")
                    .pkTextStyle(.callout)
                    .foregroundStyle(Color.danger600)
                Text("1분 안에 공원으로\n돌아오세요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                HStack(spacing: Spacing.s8) {
                    PKIllustration(assetName: "character-sad", fallbackSymbol: "pawprint.fill", size: 40)
                    Text("밖에 있는 동안은\n타이머가 멈춰요").pkTextStyle(.callout).foregroundStyle(Color.ink700)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: Spacing.s4) {
                Text("남은 시간").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                Text(DurationFormatter.clock(graceRemaining))
                    .pkTextStyle(.display)
                    .foregroundStyle(Color.danger600)
                    .monospacedDigit()
            }
            .padding(Spacing.s16)
            .frame(maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            .accessibilityElement(children: .combine)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.s16)
        .background(Color.danger100, in: RoundedRectangle(cornerRadius: Radius.r24))
        .overlay(RoundedRectangle(cornerRadius: Radius.r24).stroke(Color.danger600.opacity(0.25), lineWidth: 2))
    }
}

// MARK: - 장면 일러스트

/// 공원을 산책하는 내 캐릭터 장면. 캐릭터가 살짝살짝 흔들리고, 말풍선으로 진행 상황을 응원한다.
/// 배경은 `checkin-scene` 에셋(361×170)이고, 캐릭터 배치는 `tools/generate_art.py`의 장면 좌표와 같다.
private struct CheckInScene: View {
    let display: CheckInProgressDisplay
    let characterAssetName: String?

    private static let designWidth: CGFloat = 361
    private static let designHeight: CGFloat = 170

    var body: some View {
        GeometryReader { proxy in
            let k = proxy.size.width / Self.designWidth
            ZStack(alignment: .topLeading) {
                Image("checkin-scene").resizable().frame(width: proxy.size.width, height: proxy.size.height)
                Image(characterName)
                    .resizable().scaledToFit()
                    .pkWiggle(angle: 2.5, period: 2.0)
                    .frame(width: 111.6 * k, height: 104.4 * k)
                    .position(x: (124.2 + 55.8) * k, y: (51.2 + 52.2) * k)
                CheerBubble(text: display.cheer)
                    .position(x: proxy.size.width / 2, y: 26 * k)
            }
        }
        .aspectRatio(Self.designWidth / Self.designHeight, contentMode: .fit)
        .background(Color.leaf100)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r30))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.cheer)
    }

    private var characterName: String {
        if let characterAssetName, UIImage(named: characterAssetName) != nil { return characterAssetName }
        return "character-default"
    }
}

/// 말풍선: 흰 바탕에 굵은 외곽선(일러스트와 같은 선), 아래로 꼬리가 나온다.
private struct CheerBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .pkTextStyle(.callout)
            .foregroundStyle(Color.ink900)
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, Spacing.s8)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.ink900, lineWidth: 2.4))
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(Color.white)
                    .overlay(Triangle().stroke(Color.ink900, lineWidth: 2.4))
                    .frame(width: 14, height: 9)
                    .offset(y: 8)
            }
            .animation(.easeInOut(duration: 0.3), value: text)
            .contentTransition(.opacity)
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
            return path
        }
    }
}

// MARK: - Preview

private let previewInside = CheckInProgressDisplay(
    parkName: "보라매공원", parkType: .neighborhood, remaining: 754, stayed: 446, phase: .inside)

#Preview("공원 안") {
    CheckInProgressView(display: previewInside, onRequestCancel: {}, onShowMap: {})
}

#Preview("반경 밖(일시정지)") {
    CheckInProgressView(
        display: CheckInProgressDisplay(
            parkName: "보라매공원", parkType: .neighborhood, remaining: 754, stayed: 446,
            phase: .outOfRange(metersOutside: 80, graceRemaining: 42)),
        onRequestCancel: {}, onShowMap: {})
}

#Preview("배지 확인 중") {
    CheckInProgressView(
        display: CheckInProgressDisplay(
            parkName: "보라매공원", parkType: .neighborhood, remaining: 0, stayed: 1200, phase: .completing),
        onRequestCancel: {}, onShowMap: {})
}

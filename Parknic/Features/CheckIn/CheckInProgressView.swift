import SwiftUI

/// 12c·05a·05b — 체크인 진행. 일러스트는 에셋(`checkin-scene`, 캐릭터)으로 교체한다.
struct CheckInProgressView: View {
    let display: CheckInProgressDisplay
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
            circleButton("xmark", label: "체크인 그만두기", action: onRequestCancel)
            Spacer()
            VStack(spacing: Spacing.s4) {
                Text(display.parkType.displayName).pkTextStyle(.callout).foregroundStyle(Color.leaf600)
                Text(display.parkName).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            circleButton("map", label: "지도 보기", action: onShowMap)
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
            CheckInScene()
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

/// 공원에서 쉬는 캐릭터 장면. 에셋이 없는 동안은 단순한 자리표시자를 보여준다.
private struct CheckInScene: View {
    var body: some View {
        Group {
            if UIImage(named: "checkin-scene") != nil {
                Image("checkin-scene").resizable().scaledToFill()
            } else {
                ZStack {
                    Color.leaf100
                    HStack(spacing: Spacing.s28) {
                        Image(systemName: "tree.fill").font(.system(size: 44)).foregroundStyle(Color.leaf600)
                        Image(systemName: "pawprint.fill").font(.system(size: 52)).foregroundStyle(Color.sun500)
                        Image(systemName: "sun.max.fill").font(.system(size: 44)).foregroundStyle(Color.sun500)
                    }
                }
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r30))
        .accessibilityHidden(true)
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

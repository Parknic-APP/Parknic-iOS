import SwiftUI

// 살아 있는 느낌을 주는 가벼운 모션. '동작 줄이기'를 켠 사용자에게는 움직이지 않는다.

/// 캐릭터가 아래 가운데를 축으로 살짝살짝 흔들리며 숨 쉬듯 늘었다 줄어든다.
struct PKWiggle: ViewModifier {
    /// 좌우로 기우는 최대 각도(도)
    var angle: Double = 3
    /// 한 번 흔들리는 데 걸리는 시간(초)
    var period: Double = 2.4
    /// 캐릭터마다 어긋나게 움직이도록 주는 시작 위상
    var phase: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate * 2 * .pi / period + phase
                content
                    .rotationEffect(.degrees(sin(t) * angle), anchor: .bottom)
                    .scaleEffect(x: 1 - 0.015 * sin(t * 2), y: 1 + 0.025 * sin(t * 2), anchor: .bottom)
            }
        }
    }
}

extension View {
    func pkWiggle(angle: Double = 3, period: Double = 2.4, phase: Double = 0) -> some View {
        modifier(PKWiggle(angle: angle, period: period, phase: phase))
    }
}

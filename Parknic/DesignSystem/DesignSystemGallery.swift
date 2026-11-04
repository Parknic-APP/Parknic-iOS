import SwiftUI

/// 디자인 토큰을 한눈에 확인하는 화면. 토큰을 바꾸면 Preview로 먼저 확인한다.
struct DesignSystemGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s28) {
                section("Leaf") {
                    swatches([
                        ("leaf900", .leaf900), ("leaf600", .leaf600), ("leaf500", .leaf500),
                        ("leaf300", .leaf300), ("leaf100", .leaf100), ("leaf50", .leaf50),
                    ])
                }
                section("Sun · Danger") {
                    swatches([
                        ("sun700", .sun700), ("sun500", .sun500), ("sun300", .sun300),
                        ("sun100", .sun100), ("danger600", .danger600), ("danger100", .danger100),
                    ])
                }
                section("Ink") {
                    swatches([
                        ("ink900", .ink900), ("ink700", .ink700), ("ink500", .ink500),
                        ("ink300", .ink300), ("ink100", .ink100), ("canvas", .canvas),
                    ])
                }
                section("공원 유형") {
                    swatches(ParkType.allCases.map { ($0.displayName, $0.color) })
                }
                section("타이포그래피") {
                    VStack(alignment: .leading, spacing: Spacing.s8) {
                        Text("12:34").pkTextStyle(.timer)
                        Text("근린공원 배지").pkTextStyle(.display)
                        Text("보라매공원").pkTextStyle(.title1)
                        Text("이달의 시상대").pkTextStyle(.title2)
                        Text("여기서 체크인하기").pkTextStyle(.headline)
                        Text("공원 안에서 20분 머무르면 배지를 받아요.").pkTextStyle(.body)
                        Text("동작구 여의대방로20길 33 · 320m").pkTextStyle(.callout)
                        Text("신대방어린이공원").pkTextStyle(.caption)
                    }
                    .foregroundStyle(Color.ink900)
                }
                section("그림자") {
                    HStack(spacing: Spacing.s16) {
                        card("soft1", shadow: .soft1)
                        card("soft2", shadow: .soft2)
                    }
                }
            }
            .padding(Spacing.s16)
        }
        .background(Color.canvas)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text(title).pkTextStyle(.title2).foregroundStyle(Color.ink900)
            content()
        }
    }

    private func swatches(_ items: [(String, Color)]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s8), count: 3), spacing: Spacing.s8) {
            ForEach(items, id: \.0) { item in
                VStack(spacing: Spacing.s4) {
                    RoundedRectangle(cornerRadius: Radius.r16)
                        .fill(item.1)
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: Radius.r16).stroke(Color.ink100))
                    Text(item.0).pkTextStyle(.caption).foregroundStyle(Color.ink500)
                }
            }
        }
    }

    private func card(_ name: String, shadow: PKShadow) -> some View {
        Text(name)
            .pkTextStyle(.callout)
            .foregroundStyle(Color.ink500)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r16))
            .pkShadow(shadow)
    }
}

#Preview {
    DesignSystemGallery()
}

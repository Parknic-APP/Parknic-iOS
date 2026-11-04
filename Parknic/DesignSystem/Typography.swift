import SwiftUI

// 파크닉 디자인 시스템 v1 — 타이포그래피
// 본문은 Pretendard, 숫자·축하 문구에만 Jua. 본문은 Dynamic Type을 지원한다.
// 폰트 파일은 Parknic/Resources/Fonts/ 에 넣고 Info.plist의 "Fonts provided by application"에 등록한다.
// 파일이 없으면 SwiftUI가 시스템 폰트로 대체하므로 앱은 동작한다.

enum PKFontName {
    static let pretendardRegular = "Pretendard-Regular"
    static let pretendardSemiBold = "Pretendard-SemiBold"
    static let pretendardBold = "Pretendard-Bold"
    static let pretendardExtraBold = "Pretendard-ExtraBold"
    static let jua = "Jua-Regular"
}

struct PKTextStyle {
    let fontName: String
    let size: CGFloat
    /// 디자인의 행간 배수 (예: Body 1.6)
    let lineHeightMultiple: CGFloat
    /// 자간(pt). 디자인의 -2%는 size × -0.02
    let tracking: CGFloat
    /// Dynamic Type이 따라갈 기준 텍스트 스타일
    let relativeTo: Font.TextStyle

    var font: Font {
        .custom(fontName, size: size, relativeTo: relativeTo)
    }

    /// 기본 행간(대략 size × 1.2)을 기준으로 추가할 간격
    var lineSpacing: CGFloat {
        max(0, size * (lineHeightMultiple - 1.2))
    }
}

extension PKTextStyle {
    /// 체크인 남은 시간 — Jua 62 / 1.0
    static let timer = PKTextStyle(
        fontName: PKFontName.jua, size: 62, lineHeightMultiple: 1.0, tracking: 0, relativeTo: .largeTitle)
    /// 축하·숫자 — Jua 36 / 1.2
    static let display = PKTextStyle(
        fontName: PKFontName.jua, size: 36, lineHeightMultiple: 1.2, tracking: 0, relativeTo: .largeTitle)
    /// 공원 이름 — 24 ExtraBold / 1.3 / -2%
    static let title1 = PKTextStyle(
        fontName: PKFontName.pretendardExtraBold, size: 24, lineHeightMultiple: 1.3, tracking: -0.48, relativeTo: .title)
    /// 섹션 제목 — 18 ExtraBold / 1.35
    static let title2 = PKTextStyle(
        fontName: PKFontName.pretendardExtraBold, size: 18, lineHeightMultiple: 1.35, tracking: 0, relativeTo: .title3)
    /// 버튼 — 17 Bold
    static let headline = PKTextStyle(
        fontName: PKFontName.pretendardBold, size: 17, lineHeightMultiple: 1.2, tracking: 0, relativeTo: .headline)
    /// 본문 — 15 Regular / 1.6
    static let body = PKTextStyle(
        fontName: PKFontName.pretendardRegular, size: 15, lineHeightMultiple: 1.6, tracking: 0, relativeTo: .body)
    /// 주소·거리 — 13 SemiBold
    static let callout = PKTextStyle(
        fontName: PKFontName.pretendardSemiBold, size: 13, lineHeightMultiple: 1.3, tracking: 0, relativeTo: .callout)
    /// 라벨·마커 — 11 Bold
    static let caption = PKTextStyle(
        fontName: PKFontName.pretendardBold, size: 11, lineHeightMultiple: 1.2, tracking: 0, relativeTo: .caption)
}

extension View {
    /// 디자인 시스템 텍스트 스타일을 적용한다. 색은 호출하는 쪽에서 토큰으로 지정한다.
    func pkTextStyle(_ style: PKTextStyle) -> some View {
        self
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}

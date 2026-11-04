# 폰트

아래 폰트 파일을 이 폴더에 넣는다. 타깃 포함은 자동이고, `project.yml`의 `UIAppFonts`에 파일 이름을 등록한다(폰트를 추가하면 거기도 추가). `FontTests`가 등록 여부를 검사한다.
둘 다 SIL Open Font License라 앱에 포함해 배포할 수 있다.

| 용도 | 파일 이름 (PostScript 이름과 일치해야 함) |
|---|---|
| 본문 | `Pretendard-Regular.otf`, `Pretendard-SemiBold.otf`, `Pretendard-Bold.otf`, `Pretendard-ExtraBold.otf` |
| 숫자·축하 문구 | `Jua-Regular.ttf` |

- 이름은 `DesignSystem/Typography.swift`의 `PKFontName`과 같아야 한다.
- 파일이 없으면 시스템 폰트로 대체되어 앱은 동작하지만 디자인과 달라진다.

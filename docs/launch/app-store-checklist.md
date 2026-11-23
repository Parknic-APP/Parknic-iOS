# App Store 제출 체크리스트

> 상태 기준일: 2026-11-05. 사람이 해야 할 일의 순서는 [`owner-todo.md`](owner-todo.md). 체크된 항목은 코드에 반영됐고, 빈 항목은 사람이 해야 한다.

## 1. 앱에 반영된 것
- [x] Sign in with Apple (entitlement + 로그인 화면)
- [x] 앱 안 회원 탈퇴(확인 2단계) — 마이 > 회원 탈퇴
- [x] 리뷰 신고·유저 차단 (UGC 앱 심사 요구)
- [x] 이용약관·개인정보 처리방침 링크(마이, 로그인 화면)
- [x] 위치 권한 문구는 "앱을 사용하는 동안"만 요청(항상 허용 요청 없음)
- [x] `NSLocationWhenInUseUsageDescription`, Background Modes(Location updates)
- [x] `PrivacyInfo.xcprivacy`(UserDefaults 사용 사유 CA92.1, 수집 데이터: 정확한 위치·사용자 ID·사용자 콘텐츠, 추적 없음)
- [x] `ITSAppUsesNonExemptEncryption = NO`(HTTPS 표준 암호화만 사용)
- [x] 라이트 모드 고정, iPhone 세로 고정
- [x] Release 빌드 성공(서명 없이 확인)
- [x] 네트워크 끊김 안내(MVP 공통 처리)
- [x] 지도·공원 시트·체크인·배지·랭킹·리뷰·마이페이지(P0 전체)

## 2. 제출 전에 반드시 바꿔야 하는 것 (project.yml)
- [ ] `TERMS_URL` — 이용약관 실제 주소 (`https://parknic-gcp.duckdns.org/terms`)
- [ ] `PRIVACY_POLICY_URL` — 개인정보 처리방침 실제 주소 (현재 임시값)
- [ ] Release `API_BASE_URL` — 운영 서버 주소 (`https://parknic-gcp.duckdns.org`)
- [ ] Release 빌드가 Mock이 아니라 실서버 저장소를 쓰는지 확인(`#if DEBUG`로 Debug만 Mock)
- [ ] 앱 아이콘 최종 이미지(`Resources/Assets.xcassets/AppIcon.appiconset`) — **현재는 임시 아이콘**
- [ ] 개발 팀(Team ID) 서명 설정, 번들 ID `com.seongmo.parknic` 등록, Sign in with Apple capability 활성화

## 3. 앱에 아직 없는 것 (제출은 가능하나 알고 있어야 함)
- 최종 캐릭터·배지·일러스트 에셋(임시 SF Symbol로 대체 중, 이름 규칙: `character-<id>`, `badge-<type>`, `achievement-<code>`, `login-hero`, `checkin-scene`, `character-sad`)
- 카카오·구글·이메일 로그인, 도감, 통계, 도움돼요·정렬, 네이버 지도(모두 업데이트로 이월)
- 실기기 20분 체크인 테스트·배터리 측정(MVP 완료 기준)

## 4. App Store Connect 입력
- 앱 이름 / 부제 / 설명 / 키워드 / 카테고리(건강 및 피트니스 또는 라이프스타일)
- 연령 등급: 사용자 생성 콘텐츠(리뷰)가 있어 신고·차단 기능을 설명
- **App Privacy(앱 개인정보) 답변** — `PrivacyInfo.xcprivacy`와 같게 입력
  - 정확한 위치: 수집함 / 사용자에 연결됨 / 추적 안 함 / 목적: 앱 기능
  - 사용자 ID: 수집함 / 연결됨 / 추적 안 함 / 목적: 앱 기능
  - 기타 사용자 콘텐츠(리뷰): 수집함 / 연결됨 / 추적 안 함 / 목적: 앱 기능
- 스크린샷(6.9"·6.5" 등 필수 크기) — 지도, 공원 시트, 체크인 진행, 배지 획득, 랭킹
- 지원 URL, 마케팅 URL(선택), 개인정보 처리방침 URL

## 5. App Review 메모 (심사관에게 전달할 글, 복사해서 사용)
```
[앱 설명] 파크닉은 내 주변 공원에서 연속 20분 머무르면 배지를 받는 산책 수집 앱입니다.

[위치 사용] 위치 권한은 "앱을 사용하는 동안"만 요청합니다. 사용자가 공원 시트에서 체크인을 시작한 뒤
20분 동안 공원 반경 안에 머무르는지 확인하기 위해 체크인 중에만 위치를 사용하며, 화면을 끄거나 앱을
내려도 측정이 이어지도록 Background Modes(Location updates)를 사용합니다. 체크인이 끝나면(완료·실패·취소)
위치 수신을 즉시 중지합니다. 이동 경로는 저장하지 않고 서버에는 체크인 시작·완료 시점의 좌표만 보냅니다.

[테스트 방법] 체크인은 실제 공원 반경 안에서만 시작할 수 있습니다. 심사 환경에서는 Xcode/시뮬레이터의
위치 시뮬레이션 또는 [심사용 계정/데모 안내]를 사용해 주세요. (※ 심사용 안내는 서버 준비 후 작성)

[로그인] Sign in with Apple을 사용합니다. 앱 안에서 회원 탈퇴할 수 있습니다(마이 > 회원 탈퇴).
[UGC] 리뷰는 신고·유저 차단 기능이 있습니다(리뷰 목록의 ⋯ 버튼).
```
> 심사에서 체크인 흐름을 확인하기 어렵다는 점이 반려 사유가 되기 쉽다. 서버에 **심사용 공원(반경이 넓은 테스트 공원)** 이나
> **심사용 계정**을 두는 방안을 서버 팀과 정할 것.

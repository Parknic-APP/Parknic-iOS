# 출시까지 사람이 해야 할 일

> 앱 쪽 P0 기능은 모두 `main`에 들어갔다(테스트 342개 통과, Release 빌드 성공). 아래는 **코드로 해결할 수 없어서** 사람이 해야 하는 일이다.
> 상세 체크리스트는 [`app-store-checklist.md`](app-store-checklist.md), 서버 인계는 [`../backend-handoff.md`](../backend-handoff.md).

## 순서(막히는 정도 순)

### 1. 서버 개발 ← 가장 큰 병목
- [ ] 서버 저장소에서 [`backend-handoff.md`](../backend-handoff.md)의 P0 엔드포인트와 규칙 12개를 구현
- [ ] 앱이 "가정"한 응답 형식을 서버와 확정(재발급, 닉네임 확인, 캐릭터 목록, 체크인 세션, 공원 상세, 리뷰, 신고 사유 값 등) — 다르면 알려 주면 앱을 고친다
- [ ] 운영 서버 주소 확정 → `project.yml`의 Release `API_BASE_URL` 교체
- [ ] **심사용 테스트 공원(반경이 매우 큰 공원) 또는 심사용 계정/모드** 마련 — 심사관은 실제 공원 안에 있을 수 없다
- [ ] 서버를 실제로 연결한 뒤 앱 동작 재확인(Mock → 실서버 전환은 Release 빌드가 자동으로 수행)

### 2. 법적·정책 문서
- [ ] `docs/legal/privacy-policy-draft.md`, `terms-draft.md`의 `[ ]`를 채우고 **법률 검토** 후 웹에 게시
- [ ] 게시한 주소를 `project.yml`의 `TERMS_URL`, `PRIVACY_POLICY_URL`에 입력(현재 임시값 `parknic.example`)
- [ ] 개인정보 보호책임자·문의 이메일, 지원 URL 준비

### 3. Apple 계정·서명
- [ ] Apple Developer에서 App ID `com.seongmo.parknic` 등록, **Sign in with Apple** capability 활성화
- [ ] Xcode에서 개발 팀(Team) 선택(서명 설정). `project.yml`의 `DEVELOPMENT_TEAM`에 Team ID 입력 후 `xcodegen generate`
- [ ] App Store Connect에서 앱 생성(이름 "파크닉" 사용 가능 여부 확인, 상표·동명 앱 확인)

### 4. 디자인 에셋
- [ ] **앱 아이콘 최종 이미지**(1024×1024, 투명·모서리 둥글림 없음) — 지금은 임시 아이콘
- [ ] 캐릭터 8종(표정 3), 배지 7종 + 업적 5종, 로그인·체크인 일러스트 — 없으면 임시 심볼로 표시됨. 이름 규칙: `character-<id>`, `character-sad`, `badge-<neighborhood|children|small|sports|waterfront|culture|history>`, `achievement-<code>`, `login-hero`, `checkin-scene` (Asset Catalog에 넣기만 하면 코드 변경 없이 교체됨)
- [ ] App Store 스크린샷(지도, 공원 시트, 체크인 진행, 배지 획득, 랭킹)

### 5. 실기기 테스트 (MVP 완료 기준)
- [ ] 화면을 끄고 주머니에 넣은 채 **20분 측정 → 배지 획득**
- [ ] 반경 이탈 후 1분 뒤 실패 / 1분 안에 복귀하면 유지 / 같은 공원 하루 2번 불가
- [ ] 체크인 20분 동안 **배터리 소모 기록**(체감상 부담 없는 수준)
- [ ] 실제 공원 3곳 이상에서 확인, 실제 Apple 로그인·알림 표시 확인
- [ ] TestFlight 배포 → 지인 테스트, 크래시 0건

### 6. 제출
- [ ] App Store Connect 입력(설명·키워드·카테고리·연령 등급) — [`app-store-checklist.md`](app-store-checklist.md) 4장
- [ ] **App Privacy 답변** 입력(체크리스트 4장의 3개 항목, 앱의 `PrivacyInfo.xcprivacy`와 동일)
- [ ] **App Review 메모** 붙여넣기(체크리스트 5장, 심사용 계정/공원 안내 보완)
- [ ] 아카이브 → 업로드 → 심사 제출

## 앱에 없는 것(1차 제출에는 불필요, 업데이트로)
카카오·구글·이메일 로그인, 네이버 지도, 도감, 통계, 도움돼요·정렬, 작성자 프로필, 프로필 수정, 다크 모드

## 알아둘 것
- `Localizable.xcstrings`는 Xcode 앱이 자동으로 수정하는 경우가 있다. 커밋할 때 이 파일을 제외할 것.
- 개발 중 로그인 화면의 "개발용" 버튼은 Debug 빌드에만 있고 Release에는 들어가지 않는다.

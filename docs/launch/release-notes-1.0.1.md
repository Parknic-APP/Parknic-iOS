# 1.0.1 업데이트 노트 (서버 이전 버전)

이 버전은 서버를 새 환경(Google Cloud, 서울)으로 옮긴 첫 버전이다. 앱 1.0.0은 옛 서버를 계속 쓰고, 1.0.1부터 새 서버를 쓴다.

## App Store "이 버전의 새로운 기능" (한국어)

```
서버를 새 환경으로 이전했어요.

· 서버 이전으로 이전 버전의 계정과 기록(배지, 리뷰)은 이어지지 않고 새로 시작해요. 불편을 드려 죄송해요.
· 개인정보 처리방침이 바뀌었어요. 서버가 서울 리전의 Google Cloud로 옮겨졌어요. 자세한 내용은 앱의 로그인 화면에서 확인할 수 있어요.
· 안정성을 개선했어요.
```

## 심사 메모(App Review Notes) 추가 문구

```
이 버전부터 서버 주소가 바뀌었습니다(https://parknic-gcp.duckdns.org). 이전 버전의 계정 데이터는 이전하지 않았습니다.
한국 밖에서 심사하실 수 있도록 심사 기간에는 심사관 위치 근처의 심사용 공원을 노출합니다. 지도에서 가까운 공원을 선택해 체크인(20분)을 시작해 주세요.
```

## 제출 직전 체크
- [ ] TestFlight 업로드용 App Store Connect API 키 `fastlane/AuthKey.p8`(Git 제외)과 `MATCH_PASSWORD` 확인 — 키는 계정 소유자에게 개인 메시지로 받는다(`fastlane/SIGNING.md`)
- [ ] 서버 `REVIEW_MODE=true`와 심사용 공원 등록(`be/docs/review-mode.md`), 심사 통과 후 끄기
- [ ] 버전은 1.0.0보다 높게: `bundle exec fastlane release version:1.0.1` (또는 brew fastlane이면 `fastlane release version:1.0.1`)
- [ ] 체크인 시험용 옵션(`quick_checkin`)을 켜지 않았는지 확인(App Store 제출 빌드에는 금지)
- [ ] 새 서버 `/terms`, `/privacy`, `/support`가 200인지 확인
- [ ] 방침 시행일 이후에 배포하는지 확인(시행일은 2026년 12월 1일)

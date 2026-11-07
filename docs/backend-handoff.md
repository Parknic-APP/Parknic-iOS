# 서버 개발 인계 (iOS 앱이 기대하는 것)

> 기준 문서는 [`api-spec.md`](api-spec.md)다. 이 문서는 **앱이 이미 구현해 둔 P0 기능이 서버에 요구하는 것**을 한곳에 모았다.
> "가정"으로 표시한 항목은 앱이 임의로 정한 형식이라 서버와 맞춰 **확정**해야 한다(달라지면 앱을 고친다).
> 서버가 준비되기 전에는 앱이 Mock으로 동작하며, 서버가 생기면 `project.yml`의 `API_BASE_URL`만 바꿔 연결한다.

## 1. P0 엔드포인트 (앱이 호출하는 것)
| 기능 | Method · URL | 비고 |
|---|---|---|
| 소셜 로그인 | `POST /api/auth/login/apple` `{ token }` | 응답 `{ accessToken, refreshToken, isNewUser }` |
| 토큰 재발급 | `POST /api/auth/reissue` `{ refreshToken }` | **가정**: 응답 `{ accessToken, refreshToken }`. Refresh 교체. 401/400/403이면 앱은 로그아웃 처리 |
| 로그아웃 | `POST /api/auth/logout` | Refresh 삭제. 실패해도 앱은 기기에서 로그아웃 |
| 닉네임 확인 | `GET /api/users/nickname/check?nickname=` | **가정**: `{ available: Bool }` 또는 409 `NICKNAME_DUPLICATED` |
| 캐릭터 목록 | `GET /api/characters` | **가정**: `{ characters: [{ id, name }] }`, 8종, id는 1~8(앱 에셋 `character-<id>`) |
| 프로필 저장 | `PATCH /api/users/me` `{ nickname, characterId }` | 닉네임 중복이면 409 `NICKNAME_DUPLICATED` |
| 회원 탈퇴 | `DELETE /api/users/me` | **Apple 토큰 revoke는 서버가 한다**(심사 요구) |
| 주변 공원 | `GET /api/parks/nearby?lat&lng&radius=1000` | `myStatus`(`NONE`/`EARNED`/`EARNED_TODAY`), `myBadgeCount` 포함 |
| 공원 상세 | `GET /api/parks/{id}` | **가정**: `{ id, name, parkType, address, latitude, longitude, radiusM, averageRating(null 가능), reviewCount, myStatus, myBadgeCount }` |
| 체크인 시작 | `POST /api/check-ins` `{ parkId, lat, lng }` | **가정**: 응답 `{ id, parkId, parkName, latitude, longitude, radiusM, startedAt }`. `startedAt`은 서버 시각 |
| 진행 중 세션 | `GET /api/check-ins/current` | 없으면 **404**(가정). 앱 재실행 복구용 |
| 체크인 완료 | `POST /api/check-ins/{id}/complete` `{ lat?, lng?, pausedSeconds }` | 응답은 api-spec의 완료 응답(배지·새 업적·이번 주 순위·`canWriteReview`) |
| 체크인 실패 | `POST /api/check-ins/{id}/fail` `{ reason }` | `OUT_OF_RANGE` / `MIDNIGHT` / `APP_TERMINATED` |
| 체크인 취소 | `POST /api/check-ins/{id}/cancel` | |
| 공원 랭킹 | `GET /api/parks/{id}/rankings?month=2026-11` | `podium`(1~3등, 빈 자리는 항목 없음), `others`(4위~), `me`(`rank`는 이번 달 배지가 없으면 null) |
| 리뷰 목록 | `GET /api/parks/{id}/reviews?sort=latest&cursor=` | `{ reviews, nextCursor }`, **차단한 유저의 리뷰는 서버가 제외** |
| 리뷰 작성 | `POST /api/parks/{id}/reviews` `{ rating, content }` | 배지 없으면 403 `REVIEW_BADGE_REQUIRED`, 이미 썼으면 409 `REVIEW_ALREADY_EXISTS` |
| 리뷰 수정·삭제 | `PATCH` · `DELETE /api/reviews/{id}` | 본인 리뷰만 |
| 리뷰 신고 | `POST /api/reviews/{id}/reports` `{ reason }` | **가정**: reason `SPAM` / `ABUSE` / `INAPPROPRIATE` / `OTHER` |
| 유저 차단 | `POST /api/users/{userId}/block` | 이후 목록에서 제외 |

리뷰 항목(가정): `{ id, userId, nickname, characterId, badgeCount, rating, content, createdAt(ISO-8601 +09:00), isMine }`

## 2. 서버가 반드시 지켜야 하는 규칙 (앱은 신뢰하지 않고 서버가 최종 판정)
1. **20분 판정**: `now - startedAt - pausedSeconds ≥ 20분` 이어야 완료. `pausedSeconds`는 앱이 보고하는 "반경 밖에 있던 시간"이다(밖에 있는 동안 타이머가 멈추는 규칙, 디자인 05b). 미달이면 400 `CHECKIN_TOO_EARLY`(앱은 잠시 뒤 재요청).
2. **반경**: 시작·완료 좌표가 공원 판정 반경(`radiusM`, 면적 기반 50~500m) 안이어야 함. 아니면 400 `CHECKIN_OUT_OF_RANGE`(앱은 실패 처리).
3. **자정(KST)**: 시작 날짜와 다른 날 완료 요청이면 400 `CHECKIN_EXPIRED_MIDNIGHT`(앱은 실패 처리).
4. **하루 1개**: 같은 공원은 하루 1개. 이미 받았으면 409 `BADGE_ALREADY_EARNED_TODAY`. 다른 공원은 하루 여러 개 가능.
5. **동시 체크인 1곳**: 진행 중 세션이 있으면 시작 시 409 `CHECKIN_ALREADY_IN_PROGRESS`.
6. **세션 만료**: 앱이 `fail`을 못 보내도(네트워크 단절·종료) 서버가 오래된 진행 세션을 스스로 만료시켜야 함(앱은 재실행 시 `current`를 조회해 `APP_TERMINATED`로 실패 처리).
7. **랭킹**: 월 단위(KST) 배지 수 기준. 동점이면 그 개수에 먼저 도달한 유저가 위. 다른 월은 확정된 값.
8. **리뷰**: 배지가 있는 공원만 작성. 공원당 1개. 별점 1~5, 내용 10~300자. 본인 리뷰만 수정·삭제.
9. **차단**: 차단한 유저의 리뷰를 내 목록에서 제외. 신고는 접수 후 검토 가능한 형태로 저장.
10. **위치 좌표를 이동 경로로 저장하지 않는다**(시작·완료 시점 좌표만 받음). 개인정보 처리방침과 일치해야 함.
11. **회원 탈퇴**: 개인정보 삭제 + Apple 토큰 revoke. 앱은 성공 응답을 받아야 로그아웃 처리한다.
12. **에러 응답 형식**: `{ "code": "...", "message": "..." }` — 앱은 `code`로 분기해 한국어 문구를 보여준다(api-spec 1장 표).

## 3. 심사(App Review)를 위한 서버 준비
- 심사관은 실제 공원 반경 안에 있을 수 없다. **심사용 테스트 공원(반경이 매우 큰 공원)** 또는 **심사용 계정/모드**를 서버에 마련하고 App Review 메모에 적을 것.
- 심사 기간에는 서버가 항상 동작해야 하며, Sign in with Apple로 로그인 가능해야 한다.

# API 명세 (클라이언트 기준 초안)

> 클라이언트가 가정하는 서버 계약이다. **백엔드 저장소의 명세와 맞춰 확정**하고, 달라지면 이 문서를 먼저 고친다.
> 공통: `Content-Type: application/json`, `Authorization: Bearer <accessToken>`(인증 API 제외), 시간은 ISO-8601 `+09:00`(KST).

## 1. 공통 에러 응답

```json
{ "code": "CHECKIN_TOO_EARLY", "message": "..." }
```

사용자에게 보이는 문구는 클라이언트가 `code`로 매핑한다(서버 `message`는 로그용).

| code | HTTP | 상황 | 클라이언트 처리 |
|---|---|---|---|
| CHECKIN_OUT_OF_RANGE | 400 | 공원 반경 밖에서 체크인·완료 요청 | "공원 안에서 체크인할 수 있어요" |
| CHECKIN_ALREADY_IN_PROGRESS | 409 | 이미 진행 중인 세션이 있음 | 진행 중 세션 화면으로 이동 |
| BADGE_ALREADY_EARNED_TODAY | 409 | 오늘 이 공원 배지를 이미 받음 | "오늘 획득 완료" 상태로 갱신 |
| CHECKIN_TOO_EARLY | 400 | 20분 미달 상태에서 완료 요청 | 타이머 재동기화 |
| CHECKIN_EXPIRED_MIDNIGHT | 400 | 날짜가 바뀐 세션 완료 요청 | 실패 화면(05e) |
| REVIEW_BADGE_REQUIRED | 403 | 배지 없는 공원에 리뷰 작성 | 작성 불가 안내(08g) |
| REVIEW_ALREADY_EXISTS | 409 | 이미 리뷰를 쓴 공원 | "내 리뷰 수정"으로 전환 |
| NICKNAME_DUPLICATED | 409 | 닉네임 중복 | 중복 안내(07c) |
| TOKEN_EXPIRED | 401 | Access 토큰 만료 | 재발급 후 재시도 |

## 2. 인증 · 회원

| Method | URL | 설명 | 등급 |
|---|---|---|---|
| POST | `/api/auth/login/{provider}` | 소셜 로그인 (`apple`, `kakao`, `google`) | apple·kakao P0, google P1 |
| POST | `/api/auth/signup/email` | 이메일 가입 | P1 |
| POST | `/api/auth/login/email` | 이메일 로그인 | P1 |
| POST | `/api/auth/reissue` | 토큰 재발급 (Refresh 교체) | P0 |
| POST | `/api/auth/logout` | 로그아웃 (Refresh 삭제) | P0 |
| GET | `/api/users/nickname/check?nickname=` | 닉네임 중복 확인 | P0 |
| GET | `/api/characters` | 선택 가능한 캐릭터 목록 | P0 |
| GET / PATCH | `/api/users/me` | 내 정보 / 닉네임·캐릭터 수정 (온보딩 포함) | P0 |
| DELETE | `/api/users/me` | 회원 탈퇴 (Apple 로그인은 서버가 토큰 revoke) | P0 |
| POST / DELETE | `/api/users/{userId}/block` | 유저 차단 / 해제 | P0 |
| GET | `/api/users/me/stats` | 통계 | P1 |
| GET | `/api/users/me/collection` | 배지 도감 | P1 |
| GET | `/api/users/me/reviews` | 내 리뷰 목록 | P1 |
| GET | `/api/users/{userId}` | 다른 유저 프로필 | P1 |

닉네임 확인 응답(클라이언트 가정, 서버와 확정 필요): `{ "available": true }`. 중복이면 `available: false` 또는 409 `NICKNAME_DUPLICATED` 둘 다 중복으로 처리한다. 닉네임 규칙은 2~10자, 공백 불가로 가정한다.

마이페이지(클라이언트 가정, 서버와 확정 필요):
- `GET /api/users/me` → `{ "nickname": "나뭇잎", "characterId": 1, "characterName": "치즈냥", "createdAt": "2026-09-02T12:00:00+09:00" }` (`createdAt`은 "2026년 9월부터 산책 중"에 쓴다)
- `GET /api/users/me/stats` → `{ "totalBadges": 23, "visitedParks": 11, "currentStreak": 5, "bestStreak": 9, "podiumParks": 2 }` (`podiumParks`는 시상대 1~3등에 오른 공원 수)
- `GET /api/users/me/reviews?cursor=` → `{ "reviews": [ { "id": 7, "parkId": 1024, "parkName": "보라매공원", "rating": 5, "content": "...", "createdAt": "..." } ], "totalCount": 3, "nextCursor": null }` (최신순, 커서 기반)

도감(클라이언트 가정, 서버와 확정 필요): `GET /api/users/me/collection` → `{ "totalBadges": 23, "visitedParks": 11, "types": [ { "parkType": "NEIGHBORHOOD", "count": 9 } ], "achievements": [ { "code": "PARKS_10", "name": "서로 다른 공원 10곳", "label": "10", "achievedAt": "2026-10-19T12:00:00+09:00" | null, "progress": 11, "target": 20 } ] }`. `types`에 없는 유형은 0개로 보고, 알 수 없는 `parkType`은 무시한다. `achievedAt`이 null이면 미달성이며 `progress/target`으로 진행도를 그린다. `label`은 업적 배지 안에 들어가는 짧은 글자("첫", "10", "7일").

캐릭터 목록·프로필 저장(클라이언트 가정, 서버와 확정 필요): `GET /api/characters` → `{ "characters": [ { "id": 1, "name": "치즈냥" } ] }`(8종, 이미지는 앱의 `character-<id>` 에셋). `PATCH /api/users/me` 요청 `{ "nickname", "characterId" }`, 닉네임이 중복이면 409 `NICKNAME_DUPLICATED`. 마이페이지 [수정]에서도 같은 API를 쓰며, 닉네임을 그대로 두고 캐릭터만 바꾸면 같은 닉네임이 다시 오므로 **본인의 현재 닉네임은 중복으로 보지 않아야 한다**(앱은 현재 닉네임이면 중복 확인 API를 부르지 않는다).

체크인 요청·응답(클라이언트 가정, 서버와 확정 필요): 시작 `POST /api/check-ins` 응답과 `GET /api/check-ins/current` 응답은 같은 세션 객체 `{ id, parkId, parkName, latitude, longitude, radiusM, startedAt }`(`startedAt`은 서버 시각, 이 값으로 경과 시간을 계산). 진행 중인 세션이 없으면 `current`는 404. 완료 요청 `{ lat, lng, pausedSeconds }`: 좌표를 못 구했으면 `lat`·`lng`를 생략하고, `pausedSeconds`는 반경 밖에 있어 20분에서 뺀 시간(초, 0 이상)이다. **반경 밖에 있던 시간은 20분에 포함하지 않으므로 서버도 `now - startedAt - pausedSeconds >= 20분`으로 검증해야 한다(서버와 확정 필요).** 완료 거절 코드: `CHECKIN_TOO_EARLY`(재시도), `CHECKIN_EXPIRED_MIDNIGHT`·`CHECKIN_OUT_OF_RANGE`(실패로 종료), `BADGE_ALREADY_EARNED_TODAY`(배지 없이 종료).

공원 상세(클라이언트 가정, 서버와 확정 필요) `GET /api/parks/{parkId}` → `{ id, name, parkType, address, latitude, longitude, radiusM, averageRating, reviewCount, myStatus, myBadgeCount }`(`averageRating`은 리뷰가 없으면 null).

재발급 요청(클라이언트 가정, 서버와 확정 필요): `{ "refreshToken" }` → 응답: `{ "accessToken", "refreshToken" }`

로그인 요청: `{ "token": "<소셜 SDK 토큰>" }` → 응답: `{ "accessToken", "refreshToken", "isNewUser" }`
`isNewUser`가 true면 온보딩(닉네임·캐릭터)으로 보낸다.

통계 응답 예 (`maxStreak`는 디자인의 "최고 9일" 때문에 필요 — 서버와 합의):
```json
{ "totalBadges": 23, "visitedParks": 11, "currentStreak": 5, "maxStreak": 9, "podiumParks": 2 }
```

## 3. 공원 · 체크인 · 랭킹

| Method | URL | 설명 | 등급 |
|---|---|---|---|
| GET | `/api/parks/nearby?lat=&lng=&radius=1000` | 주변 공원 + 내 상태 | P0 |
| GET | `/api/parks/{parkId}` | 공원 상세 | P0 |
| POST | `/api/check-ins` | 체크인 시작 `{ parkId, lat, lng }` | P0 |
| GET | `/api/check-ins/current` | 진행 중 세션 (재실행 복구용) | P0 |
| POST | `/api/check-ins/{sessionId}/complete` | 20분 달성 → 배지 지급 `{ lat, lng }` | P0 |
| POST | `/api/check-ins/{sessionId}/fail` | 실패 `{ reason }` (`OUT_OF_RANGE`, `MIDNIGHT`, `APP_TERMINATED`) | P0 |
| POST | `/api/check-ins/{sessionId}/cancel` | 사용자 취소 | P0 |
| GET | `/api/parks/{parkId}/rankings?month=2026-11` | 월간 시상대 + 내 순위 (`month` 생략 시 이번 달) | P0, 지난 달 P1 |

주변 공원 응답 예:
```json
{
  "parks": [
    {
      "id": 1024, "name": "보라매공원", "parkType": "NEIGHBORHOOD",
      "latitude": 37.4934, "longitude": 126.9209,
      "radiusM": 180, "distanceM": 320,
      "myStatus": "EARNED", "myBadgeCount": 3
    }
  ]
}
```
- `myStatus`: `NONE` / `EARNED` / `EARNED_TODAY`
- `parkType`: `NEIGHBORHOOD`(근린) `CHILDREN`(어린이) `SMALL`(소) `SPORTS`(체육) `WATERFRONT`(수변) `CULTURE`(문화) `HISTORY`(역사)
- `radiusM`: 서버가 면적 기반으로 계산한 판정 반경(50~500m)

체크인 완료 응답 예 (`rankChange`, `badgesToPodium`은 06a 화면에 필요 — 서버와 합의):
```json
{
  "badge": { "parkId": 1024, "parkName": "보라매공원", "parkType": "NEIGHBORHOOD", "earnedAt": "2026-11-04T15:32:10+09:00" },
  "newAchievements": [ { "code": "PARKS_10", "name": "공원 10곳 정복" } ],
  "monthlyRanking": { "rank": 5, "badgeCount": 4, "rankChange": 1, "badgesToPodium": 3 },
  "canWriteReview": true
}
```

랭킹 응답 예:
```json
{
  "month": "2026-11",
  "podium": [
    { "rank": 1, "userId": 7, "nickname": "두부산책", "characterId": 5, "badgeCount": 12 },
    { "rank": 2, "userId": 3, "nickname": "초록발", "characterId": 3, "badgeCount": 9 },
    { "rank": 3, "userId": 9, "nickname": "오리걸음", "characterId": 8, "badgeCount": 6 }
  ],
  "others": [ { "rank": 4, "userId": 11, "nickname": "구름빵", "characterId": 6, "badgeCount": 7 } ],
  "me": { "rank": 17, "badgeCount": 4 }
}
```
- 동점이면 그 개수에 먼저 도달한 유저가 위다(서버 처리).
- 시상대 자리가 비면 `podium`에 해당 순위가 없다 → 빈 단상으로 표시.

## 4. 리뷰

| Method | URL | 설명 | 등급 |
|---|---|---|---|
| GET | `/api/parks/{parkId}/reviews?sort=latest&cursor=` | 목록 (`sort`: `latest`, `likes`, `rating`) | latest P0, 나머지 P1 |
| POST | `/api/parks/{parkId}/reviews` | 작성 `{ rating, content }` | P0 |
| PATCH / DELETE | `/api/reviews/{reviewId}` | 수정 / 삭제 | P0 |
| POST | `/api/reviews/{reviewId}/reports` | 신고 `{ reason }` | P0 |
| POST / DELETE | `/api/reviews/{reviewId}/likes` | 도움돼요 / 취소 | P1 |

- 리뷰는 **별점(1~5) + 텍스트**만 있다. 키워드 태그는 1차에서 제외.
- 차단한 유저의 리뷰는 서버가 목록에서 제외한다.
- 목록은 커서 기반 페이지네이션: `{ "reviews": [...], "nextCursor": "..." }` (`nextCursor`가 null이면 끝)

## 5. 클라이언트 규칙
- 체크인 시작·완료 요청에만 좌표를 보낸다. 이동 경로는 서버에 보내지 않는다.
- 서버가 최종 판정한다. 클라이언트는 20분이 지났다고 판단되면 `complete`를 요청할 뿐이다.
- 시간 계산은 서버가 준 `startedAt` 기준으로 한다.

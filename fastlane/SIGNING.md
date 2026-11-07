# 서명 인증서 공유와 TestFlight 업로드 (fastlane match)

`fastlane/README.md`는 fastlane이 실행할 때마다 자동 생성하는 레인 목록이다. 사용 방법은 이 문서에 적는다.

Apple Developer 팀(`BBVZV8T99P`)은 Individual 가입이라 계정 소유자만 인증서·프로필을 만들 수 있다.
그래서 소유자가 match로 인증서를 만들어 비공개 저장소(`Parknic-certificates`)에 암호화해 올리고,
팀원은 `readonly`로 받아 설치한다. 팀원은 Apple 계정 접근 권한이 없어도 된다.

## 처음 한 번 (팀원)

```bash
cd fe
bundle install
bundle exec fastlane certs        # MATCH_PASSWORD를 묻는다. 소유자에게 개인 메시지로 받는다.
```

그 다음 `Config/Signing.xcconfig`(Git 제외)를 만든다.

```
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = BBVZV8T99P
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER = match Development com.hwangsanghwan.parknic
CODE_SIGN_ENTITLEMENTS = Parknic/App/Parknic.entitlements
```

`xcodegen generate` 후 Xcode를 열면 Team이 `hwang sanghwan`으로 잡히고 실기기 실행과 Apple 로그인이 된다.
실기기는 개발 프로필에 등록된 기기만 설치된다(새 기기는 아래 "인증서 만들기·갱신").

## TestFlight 업로드

App Store Connect API 키 `fastlane/AuthKey.p8`(Git 제외)가 필요하다. 팀원은 소유자에게 개인 메시지로 받는다.

```bash
bundle exec fastlane release version:1.0.0              # 빌드 번호는 TestFlight의 마지막 번호 + 1로 자동
bundle exec fastlane build version:1.0.0 build_number:3 # 업로드 없이 .ipa만 만들어 확인
```

버전·빌드 번호는 Info.plist가 아니라 빌드 설정(`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)에서 오며 release가 덮어쓴다.
Release는 match 배포 프로필로 수동 서명하므로 Xcode에서 Archive를 직접 하지 않아도 된다.

## 인증서 만들기·갱신 (계정 소유자만)

기기가 추가되거나 인증서가 만료되면 소유자가 다시 만든다. 팀원은 `bundle exec fastlane certs`를 다시 돌리면 된다.
Apple 인증은 App Store Connect API 키(`fastlane/api_key.json`, Git 제외)로 한다.

```bash
# 새 기기 등록(UDID는 Finder에서 iPhone 선택 → 모델명 클릭)
bundle exec fastlane run register_device name:"이름 iPhone" udid:"00008xxx-xxxxxxxxxxxxxxxx" api_key_path:fastlane/api_key.json
# 개발·배포 프로필 생성/갱신 (기기 목록 반영)
bundle exec fastlane match development --readonly false --force_for_new_devices --api_key_path fastlane/api_key.json
bundle exec fastlane match appstore --readonly false --api_key_path fastlane/api_key.json
```

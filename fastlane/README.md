fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certs

```sh
[bundle exec] fastlane ios certs
```

개발·배포 인증서와 프로필을 받아 설치한다(팀원용, Apple 계정 접근 불필요)

### ios build

```sh
[bundle exec] fastlane ios build
```

App Store용 .ipa를 만든다(업로드 없음). 예: bundle exec fastlane build version:1.0.0 build_number:1

### ios release

```sh
[bundle exec] fastlane ios release
```

TestFlight 업로드. 예: bundle exec fastlane release version:1.0.0

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

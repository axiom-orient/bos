# Testing Guide

## Goal
- `swift test`가 로컬 환경 차이 때문에 흔들리지 않도록 실행 조건을 고정한다.
- `doctor`/`verify`처럼 Xcode 경로에 민감한 명령은 전역 설정 변경 없이 재현 가능하게 만든다.

## What Changed
- `Package.swift`의 `CoreTests` target에 `swift-testing` 의존성을 명시했다.
- `CLIJsonOutputIntegrationTests`는 `doctor` 기본 scope(`core`)와 `release-init` scope를 분리해서 검증한다.
- `doctor --for core` 성공 경로가 필요할 때는 테스트 내부에서 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 주입한다.
- onboarding SSOT와 `app-register`는 별도 integration test로 고정했다.

## Why `no such module 'Testing'` Happened
- 현재 머신의 기본 Swift toolchain만 믿으면 `import Testing` 해석이 흔들릴 수 있다.
- 테스트 target이 `Testing`을 명시적으로 의존하지 않으면 `swift test`가 환경에 따라 실패할 수 있다.
- 해결은 문서 지시만이 아니라 패키지 선언 자체에 테스트 런타임 의존성을 기록하는 것이다.

## Recommended Commands
```bash
swift test --filter AppRegistrationIntegrationTests
swift test --filter CLIJsonOutputIntegrationTests
swift test
swift build -c release
```

## Xcode-Sensitive Commands
- `bos doctor --for core`
- `bos verify`

전역 `xcode-select`를 바꾸지 않으려면 아래처럼 실행한다.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos doctor --for core
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

## Release-Check Commands
- `bos doctor --for app-register`
- `bos doctor --for release-check`
- `bos doctor --for release-run`
- `bos app-register`
- `bos release-init`
- `bos release-check`
- `bos release-run --stage build`

`release-check`는 실제 네트워크와 signing credential을 사용한다. 기본 mode는 read-only다.

```bash
bos doctor --for app-register
bos app-register
bos doctor --for release-check
bos release-init
bos release-check
# write-capable cert sync가 필요할 때만
bos release-check --mode sync-certs --allow-write
bos doctor --for release-run
bos release-run --stage beta
```

## Toolchain Lock Migration
- `config/toolchain.lock.yaml`의 `schemaVersion: 1`은 지원하지 않는다.
- legacy lock을 발견하면 삭제 후 `bos doctor`를 다시 실행해 schemaVersion 2를 재생성한다.

## Test Intent Map
- `CLIJsonOutputIntegrationTests`: CLI 계약, doctor 기본/명시 scope, legacy lock migration message
- `DoctorEngineIntegrationTests`: toolchain policy 판정 자체
- `AppRegistrationIntegrationTests`: app-register metadata resolution, deterministic SKU, profile backfill, ASC env validation
- `ApplyEngineIntegrationTests`: 생성/멱등/managed block drift
- `VerifyEngineIntegrationTests`: 검증 단계 순서, 실패 분류, 상태 동기화
- `ReleaseInitEngineIntegrationTests`: signing preflight, fastlane scaffold, 상태 동기화
- `ReleaseCheckEngineIntegrationTests`: release-check mode별 단계 순서, 실패 분류, state sync, secret redaction
- `ReleaseRunEngineIntegrationTests`: build/upload wrapper 단계, signing mode 선택, IPA artifact 경로, state sync

## Practical Notes
- `doctor` 기본 실행은 signing 템플릿을 만들지 않는다. release 준비 전에는 `--for release-init`를 명시해야 한다.
- `swift test`가 녹색이어도 generated iOS 프로젝트의 실제 build/test는 `bos verify`로 별도 확인해야 한다.
- generated App template은 debug build에서 code signing을 끄므로, Apple Team ID가 들어 있어도 provisioning profile 없이 초기 `bos verify`를 재현할 수 있다.
- `app-register`는 실제 App Store Connect에 붙지만 idempotent하다. bundle ID/app이 이미 있으면 `existing`으로 끝나고 profile/artifact만 갱신한다.
- `MATCH_GIT_URL` 기본 위치는 `.bos/config/profile.yaml`의 `release.matchGitURL`이다. `.bos/config/signing.env`는 `ASC_*`와 `MATCH_PASSWORD` secret 위주로 유지한다.
- `release-init`는 scaffold 생성까지다. 실제 App Store Connect/match 접근은 `release-check`가 담당한다.
- `release-check` 기본 mode(`readonly-certs`)는 read-only certificate fetch까지 본다. write sync는 `--mode sync-certs --allow-write`가 없으면 실행되지 않는다.
- `release-run`은 `release-init`와 `release-check`를 내부에서 다시 거친 뒤 IPA build/upload/submit를 실행한다.
- `release-run` stage는 `build|beta|release|submit` 네 가지만 허용한다.

## Live Runbook
1. 실제 릴리즈용이 아닌 테스트 credential을 준비한다.
2. 임시 작업 폴더에 `.bos/config/profile.yaml`을 만들고 `companyName`, `appIdentifier`, `appleTeamId`, `release.matchGitURL`를 채운다.
3. `bos doctor --for app-register`로 App Store Connect secret preflight를 먼저 확인한다.
4. 이미 존재하는 bundle id로 `bos app-register --format json`을 실행해 `existing/existing` idempotent 경로를 먼저 검증한다.
5. 신규 bundle id를 실제로 만들 준비가 됐을 때만 `bos app-register`를 새 값으로 다시 실행한다.
6. `bos release-init`로 `fastlane/Fastfile`, `Appfile`, `Matchfile`를 생성한다.
7. `bos release-check`로 App Store Connect auth와 read-only cert fetch를 검증한다.
8. write sync가 필요한 경우에만 `bos release-check --mode sync-certs --allow-write`를 실행한다.
9. build/upload/submit smoke가 필요하면 `bos release-run --stage build|beta|release|submit`를 실행한다.
10. 결과는 `<project-root>/.bos/artifacts/app-register/`, `<project-root>/.bos/artifacts/release-check/`, `<project-root>/.bos/artifacts/release-run/`, `.bos/state/bos.state.yaml`에서 확인한다.

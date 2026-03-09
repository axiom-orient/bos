# Product Guide

## 1) Input Contract
`plan`의 기본 입력은 `PLAN/` 문서 폴더입니다.

단일 경로(권장):
- `--plan-dir <path>`
- profile은 `.bos/config/profile.yaml` 기본 경로를 사용하고, 필요시 `--profile <path>`로 override
- onboarding 운영값은 profile SSOT에 둔다.
  - `identity.companyName`
  - `identity.appName`
  - `identity.appIdentifier`
  - `identity.appleTeamId`
  - `release.primaryLanguage`
  - `release.sku`
  - `release.matchGitURL`
- precedence는 `CLI override > profile > PRD marker > deterministic default`다.
- deterministic default:
  - `appName`: project 이름 fallback
  - `primaryLanguage`: `en-US` 기본, `ko-KR` 지원
  - `sku`: `companySlugOrBundleSeed.appSlug.hash8(appIdentifier)`

자동 추출 규칙:
- `FR-001` -> `REQ-001`
- 화면 키워드(`Today`, `Shelf`, `Capture`, `Focus`, `Reflection`, `Weekly Review`, `Settings`, `Permission+Voice`) -> `SCR_...`
- 도메인 heading(`11.1 Item`, `2.3 FocusSession`) -> `Entity`

PRD 직접 입력(`--prd`)도 지원하며, 이 경우 아래 마커를 그대로 읽습니다.

- `Project:`
- `App Identifier:`
- `Apple Team ID:`
- `Company Name:`
- `App Name:`
- `Primary Language:`
- `SKU:`
- `REQ-...`
- `SCR_...`
- `Entity:`

예시:

```md
# PRD

Project: Daycraft
App Identifier: com.axiomorient.daycraft
Apple Team ID: A1B2C3D4E5
Company Name: Axiom Orient
App Name: Daycraft
Primary Language: ko-KR

## Requirements
- REQ-001 오늘 카드 로드

## Screens
- SCR_TODAY_HOME

## Entities
- Entity: User
```

## 2) Module Generation Policy
`apply --mode init` 기본 생성 순서:
1. App (one-time)
2. Domains
3. Features
4. Services
5. Shared
6. Root bootstrap guides (`AGENTS.md`, `CLAUDE.md`, `Rules/`)

규칙:
- 이미 존재하는 모듈 파일은 재생성하지 않음
- 이미 존재하는 bootstrap guide 파일/폴더도 덮어쓰지 않음
- `incremental` 모드에서는 managed block 드리프트만 검사/복구(`--fix`)함

## 3) Verify Policy
`verify`는 다음 순서로 실행:
1. `tuist install`
2. `tuist generate --no-open`
3. `xcodebuild build -scheme <app-scheme>`
4. `xcodebuild test -scheme <app-scheme>`

생성된 App 프로젝트는 debug 설정에서 `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`를 사용한다.
- 목적: 초기 scaffold 직후에도 provisioning profile 없이 `verify` smoke gate를 먼저 통과시킬 수 있게 한다.
- release signing 검증은 `doctor --for release-init`와 `release-init`이 맡는다.

스킴 결정 규칙(단일):
- 우선: `Projects/App/Project.swift`의 `appName`
- fallback: `profile.name`을 PascalCase로 정규화 후 `App` suffix

## 3-1) App Register Policy
`app-register`는 App Store Connect 앱 등록 책임만 맡는다.

입력 우선순위:
1. CLI flag
2. `.bos/config/profile.yaml`
3. `.bos/plan/blueprint.yaml`
4. deterministic default

결정 규칙:
- `appIdentifier`, `appleTeamId`는 반드시 최종적으로 결정돼야 한다.
- `appName`이 없으면 project 이름 또는 bundle id terminal token으로 보정한다.
- `primaryLanguage`는 `en-US`/`ko-KR`만 허용한다.
- `sku`가 비어 있으면 `companyName` 우선, 없으면 bundle id prefix seed fallback으로 결정한다.
- `matchGitURL`는 profile SSOT를 우선 사용하고, legacy env fallback을 허용한다.

외부 동작:
- bundle ID가 없으면 생성한다.
- app record가 없으면 생성한다.
- 이미 존재하면 다시 만들지 않고 `existing`으로 종료한다.

출력:
- human/json 둘 다 지원
- artifact: `<project-root>/.bos/artifacts/app-register/`
- profile: resolved metadata로 재기록

## 3-2) Release Check Policy
`release-check`는 실제 외부 release readiness를 본다.

mode별 동작:
1. `connectivity`
   - signing env 형식 검증
   - `fastlane/Fastfile|Appfile|Matchfile` 존재 확인
   - `git ls-remote <MATCH_GIT_URL> HEAD`
   - App Store Connect API JWT를 직접 만들어 `GET /v1/apps?limit=1` 요청
2. `readonly-certs` (기본)
   - `connectivity` 전체
   - `fastlane ios certs_readonly`
3. `sync-certs`
   - `connectivity` 전체
   - `fastlane ios certs`
   - 반드시 `--allow-write` 필요

주의:
- `release-check`는 실제 네트워크와 외부 자격증명을 사용한다.
- 기본 mode는 read-only지만, `sync-certs`는 원격 signing 자산을 변경할 수 있다.
- `release-check`는 `release-init`가 만든 scaffold를 전제로 한다. 없으면 먼저 `bos release-init`를 실행한다.

## 3-3) Release Run Policy
`release-run`은 실제 배포 실행 표면이다.

단일 경로:
1. `release-init`로 fastlane scaffold를 맞춘다.
2. `release-check`를 read-only 또는 write-capable mode로 실행한다.
3. `tuist install/generate`로 workspace를 만든다.
4. `fastlane build`로 IPA를 만든다.
5. stage에 따라 upload/submit를 실행한다.

stage:
- `build`: IPA만 생성
- `beta`: TestFlight 업로드
- `release`: App Store 업로드
- `submit`: App Store 업로드 후 review submit

원칙:
- `release-run`은 내부에서 `release-init`를 다시 실행해 scaffold drift를 허용하지 않는다.
- signing repo write가 필요할 때만 `--allow-signing-write`를 사용한다.
- artifact는 `<project-root>/.bos/artifacts/release-run/`에 남는다.

## 3-4) Doctor Policy
- `--project-root` 생략 시 현재 터미널 경로(CWD)를 검사한다.
- `doctor`는 toolchain lock을 정책으로 해석한다.
  - `exact`: 완전 일치
  - `semver-range`: 범위 일치(예: `>=6.0 <7.0`)
- `--for` 생략 시 기본 scope는 `core`이다.
- `requiredFor`에 포함된 명령만 blocking 판정한다.
  - 예: `fastlane`이 `release-init`에만 required면 `--for core` 검사에서는 권고(recommended)만 출력
- `--for`로 검사 범위를 선택한다.
  - `core`(기본): `plan/apply/verify`
  - `all`: `plan/apply/verify/app-register/release-init/release-check/release-run`
  - 개별: `plan|apply|verify|app-register|release-init|release-check|release-run`
- 누락 required 도구 자동 설치를 기본으로 수행한다.
- lock 파일 없으면 자동 생성 (`config/toolchain.lock.yaml`)
- lock 경로는 `config/toolchain.lock.yaml`만 지원(`.bos/config/toolchain.lock.yaml` 미지원)
- legacy `schemaVersion: 1` lock 파일은 지원하지 않는다.
  - 기존 파일을 삭제하고 `bos doctor`를 다시 실행해 v2 policy를 재생성한다.
- signing env 파일 `.bos/config/signing.env`를 자동 로드한다(동일 키의 비어있지 않은 shell env가 우선).
- signing env 파일 템플릿은 `--for app-register`, `--for release-init`, `--for release-check`, `--for release-run`, `--for all`에서 자동 생성한다.
- signing env 템플릿은 owner-only 권한(`0600`)으로 생성/보정한다.
- fastlane 설치는 `brew install fastlane` 단일 경로를 사용한다.
  - `brew`가 없으면 Homebrew 설치 스크립트를 먼저 실행한다.
  - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- `--for app-register`, `--for release-init`, `--for release-check`, `--for release-run`, `--for all`에서는 signing env preflight를 추가로 수행한다.
  - secret 파일 필수 키: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8_BASE64`, `MATCH_PASSWORD`
  - release preflight 필수 값: 위 4개 + profile `release.matchGitURL`
  - `MATCH_GIT_URL` shell/env fallback도 legacy 호환으로 허용
  - 형식 규칙: `ASC_ISSUER_ID`(UUID), `ASC_KEY_ID`(대문자/숫자 10자리), `ASC_KEY_P8_BASE64`(base64), `MATCH_GIT_URL`(git/https/ssh)
- `--for release-check`, `--for release-run`에서는 `fastlane`, `git`, signing env가 모두 required다.
- `--for app-register`는 App Store Connect secret preflight만 required다.
- `core`/`verify` 경로는 active developer dir가 Xcode를 가리켜야 한다.
  - 전역 `xcode-select`를 바꾸지 않으려면 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 사용한다.

## 4) Artifact Policy
- 프로젝트 루트에는 로그/임시 JSON을 남기지 않음
- 모든 실행 아티팩트는 `<project-root>/.bos/artifacts/<command>/` 하위에 on-demand 생성

## 5) Lock/State Path Policy
- lock/state/plan 파일은 역할별로 분리한다.
- 경로:
  - `config/toolchain.lock.yaml`
  - `.bos/config/profile.yaml`
  - `.bos/config/signing.env`
  - `.bos/plan/blueprint.yaml`
  - `.bos/state/bos.state.yaml`
- profile 기본 경로:
  - `.bos/config/profile.yaml`
- `verify`/`release-init` 결과는 `.bos/state/bos.state.yaml`의 summary 필드에 동기화된다.
- 루트에는 `prd.md`, `profile.yaml`를 두지 않는 것을 기본 정책으로 한다.

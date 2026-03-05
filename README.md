# bos

`bos`는 iOS 프로젝트 초기 설정 자동화 CLI입니다.
핵심 목표는 **개발 기능 구현이 아니라 설정/생성/검증 자동화**입니다.

## 0.1.0에서 바로 할 수 있는 일
- `PLAN/` 또는 PRD에서 blueprint를 자동 생성할 수 있다.
- Tuist/TMA 기반 앱 골격을 반복 실행해도 안전하게 생성/갱신할 수 있다.
- `verify`로 `tuist/xcodebuild` 검증 게이트를 한 번에 실행할 수 있다.
- `release-init`으로 fastlane 기본 파일과 lane을 즉시 준비할 수 있다.
- `doctor`로 도구 버전/누락/release signing 환경을 사전에 점검할 수 있다.

## Core Scope
- `plan`: 기획 문서(PRD) -> `.bos/plan/blueprint.yaml` 생성
- `apply`: Tuist/TMA 기반 프로젝트 골격 생성
- `verify`: `tuist`/`xcodebuild` 스모크 검증
- `release-init`: `fastlane` 기본 파일 생성
- `doctor`: toolchain 정책 검사 + 설치 가이드/자동 설치

## Single Best Path
```bash
bos doctor
bos plan --plan-dir ./PLAN --app-identifier com.example.app --apple-team-id ABCD123456
bos apply --mode init
bos verify
# release-init 전 .bos/config/signing.env 값을 채운 뒤 재검증
bos doctor
bos release-init
```

## Doctor Policy
- `toolchain.lock`는 고정 버전 문자열이 아니라 정책으로 해석된다.
- `--project-root`를 생략하면 **현재 터미널 경로(CWD)** 를 기준으로 동작한다.
- `--for`를 생략하면 기본값은 `release-init`이다.
- 기본 실행은 release 준비를 목표로 동작한다.
  - `config/toolchain.lock.yaml` 자동 생성
  - `.bos/config/signing.env` 템플릿 자동 생성(없을 때)
  - required 도구 자동 설치 시도(기본)
- 검사 범위:
  - `--for release-init` (기본)
  - `--for core`
  - `--for all`
  - `--for plan|apply|verify|release-init`
- lock 파일이 없으면 자동으로 `config/toolchain.lock.yaml`를 생성한다.
- lock 경로는 `config/toolchain.lock.yaml` 단일 경로만 지원한다(`.bos/config/toolchain.lock.yaml` 미지원).
- signing env는 `.bos/config/signing.env`를 자동 로드한다(동일 키의 비어있지 않은 shell env가 우선).
- signing env 템플릿은 owner-only 권한(`0600`)으로 생성/보정한다.
- `--for release-init` 또는 `--for all`에서는 signing env preflight를 수행한다.
  - 필수 키: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8_BASE64`, `MATCH_GIT_URL`, `MATCH_PASSWORD`
  - 형식: `ASC_ISSUER_ID`(UUID), `ASC_KEY_ID`(대문자/숫자 10자리), `ASC_KEY_P8_BASE64`(base64), `MATCH_GIT_URL`(git/https/ssh URL)
- fastlane 자동 설치 정책:
  - 1순위: `brew install fastlane`
  - `brew`가 없으면 Homebrew 설치 스크립트 실행 후 `brew install fastlane`
    - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Typical Install Commands
- Tuist: `brew install tuist`
- Fastlane: `brew install fastlane`
- Swift toolchain: `xcode-select --install` (필요 시 `brew install swift`)

## Planning Input (Preferred)
- 권장 입력은 `PLAN/` 폴더다.
- profile 기본 위치는 `.bos/config/profile.yaml` 이고, 없으면 기본 profile이 자동 생성된다.
- `plan`은 `FR-###` -> `REQ-###`, 화면 키워드 -> `SCR_...`, 도메인 heading -> `Entity`를 자동 추출한다.
- `App Identifier`, `Apple Team ID`는 문서 마커 또는 CLI flag 중 하나로 제공한다.

### PRD Fallback
직접 PRD를 쓰는 경우 아래 마커 6개를 넣으면 된다.
1. `Project: <Name>`
2. `App Identifier: <bundle.id>`
3. `Apple Team ID: <TEAMID>`
4. `REQ-...` 1개 이상
5. `SCR_...` 1개 이상
6. `Entity: ...` 1개 이상

## Generation Rules
- `apply --mode init` 순서:
1. App (최초 1회)
2. Domain
3. Feature
4. Service
5. Shared
6. Bootstrap guide files (`AGENTS.md`, `CLAUDE.md`, `Rules/`) 복사
- 이미 존재하는 파일은 덮어쓰지 않음(멱등)
- 루트 최소 생성물: `Tuist.swift`, `Workspace.swift`, `Tuist/Package.swift`, `Tuist/Plugins/tma/**`
- 기본 가이드 생성물: `AGENTS.md`, `CLAUDE.md`, `Rules/**`
- 모듈 생성 위치: `Projects/**/Project.swift` (`Modules/` 폴더 생성 없음)
- 상태/설정 파일 경로:
  - `config/toolchain.lock.yaml`
  - `.bos/config/signing.env`
  - `.bos/plan/blueprint.yaml`
  - `.bos/state/bos.state.yaml`

### Default Tuist Package Dependencies
`apply --mode init`가 생성하는 `Tuist/Package.swift`에는 아래 의존성이 기본 포함된다.
- `swift-composable-architecture` (`from: 1.24.1`)
- `swift-dependencies` (`from: 1.11.0`)
- `swift-navigation` (`from: 2.4.0`)
- `sqlite-data` (`from: 1.6.0`)
- `swift-identified-collections` (`from: 1.1.0`)

## Runtime Output Policy
- 임시 로그/JSON 아티팩트는 프로젝트 루트에 남기지 않음
- 실행 결과 아티팩트 위치: `<project-root>/.bos/artifacts/<command>/...` (실행 시점에 on-demand 생성)
- 입력 정책: 루트에 `prd.md`, `profile.yaml`를 생성하지 않는다. 입력은 `PLAN/`, `docs/`, `.bos/config/` 하위에 둔다.

## Git Tracking Policy (`.bos/`)
- 커밋 대상:
  - `config/toolchain.lock.yaml` (팀 공통 toolchain 정책)
- 커밋 제외:
  - `.bos/config/profile.yaml` (로컬/환경별 기본 profile)
  - `.bos/config/signing.env` (로컬 signing secret)
  - `.bos/plan/**`, `.bos/state/**` (실행 산출물/상태 파일)

## Repository Layout (Minimal)
- `Sources/`
- `Tests/`
- `docs/`
- `Package.swift`
- `Package.resolved`
- `config/toolchain.lock.yaml`

## Why No `project/` Folder
- 이 저장소는 Swift Package Manager 기반 CLI이므로 표준 루트 구조(`Package.swift` + `Sources/` + `Tests/`)를 유지한다.
- `project/`로 한 번 더 감싸면 SwiftPM 기본 규칙을 깨고 불필요한 경로 설정만 늘어난다.
- iOS 산출물은 bos 저장소 안이 아니라 `--project-root` 대상 폴더에 생성된다.

## Docs
- [Product Guide](./docs/PRODUCT_GUIDE.md)
- [Implementation Plan](./docs/IMPLEMENTATION-PLAN.md)
- [Tasks](./docs/TASKS.md)

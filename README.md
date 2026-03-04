# bos

`bos`는 iOS 프로젝트 초기 설정 자동화 CLI입니다.
핵심 목표는 **개발 기능 구현이 아니라 설정/생성/검증 자동화**입니다.

## Core Scope
- `plan`: 기획 문서(PRD) -> `.bos/plan/blueprint.yaml` 생성
- `apply`: Tuist/TMA 기반 프로젝트 골격 생성
- `verify`: `tuist`/`xcodebuild` 스모크 검증
- `release-init`: `fastlane` 기본 파일 생성
- `doctor`: toolchain 정책 검사 + 설치 가이드/자동 설치

## Single Best Path
```bash
bos doctor
# profile 위치 권장: ./.bos/config/profile.yaml
bos plan --plan-dir ./PLAN --out ./.bos/plan/blueprint.yaml --app-identifier com.example.app --apple-team-id ABCD123456
bos apply --blueprint ./.bos/plan/blueprint.yaml --mode init
bos verify
bos release-init --blueprint ./.bos/plan/blueprint.yaml
```

## Doctor Policy
- `toolchain.lock`는 고정 버전 문자열이 아니라 정책으로 해석된다.
- `--project-root`를 생략하면 **현재 터미널 경로(CWD)** 를 기준으로 동작한다.
- `--for`를 생략하면 기본값은 `core`(`plan/apply/verify`)다.
- 기본 검사 범위는 `core`(`plan/apply/verify`)이며, `fastlane` 누락은 `release-init` 전까지 권고 수준이다.
- 검사 범위:
  - `--for core` (기본)
  - `--for all`
  - `--for plan|apply|verify|release-init`
- lock 파일이 없으면 `--init-lock`로 `.bos/config/toolchain.lock.yaml`를 생성할 수 있다.
- 누락 도구 설치:
  - 안내만: `bos doctor --project-root . --for all`
  - 자동 설치 시도: `bos doctor --project-root . --for all --install`

### Typical Install Commands
- Tuist: `brew install tuist`
- Fastlane: `brew install fastlane` 또는 `gem install fastlane -NV`
- Swift toolchain: `xcode-select --install` (필요 시 `brew install swift`)

## Planning Input (Preferred)
- 권장 입력은 `PLAN/` 폴더다.
- profile 기본 위치는 `.bos/config/profile.yaml` 이다.
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
- 상태/설정 파일은 숨김 폴더 `.bos/` 하위로 분리:
  - `.bos/config/toolchain.lock.yaml`
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
- 실행 결과 아티팩트 위치: `/Users/axient/repository/bos/temp/<command>/...` (실행 시점에 on-demand 생성)
- 입력 정책: 루트에 `prd.md`, `profile.yaml`를 생성하지 않는다. 입력은 `PLAN/`, `docs/`, `.bos/config/` 하위에 둔다.

## Repository Layout (Minimal)
- `Sources/`
- `Tests/`
- `docs/`
- `Package.swift`
- `Package.resolved`
- `.bos/config/toolchain.lock.yaml`

## Why No `project/` Folder
- 이 저장소는 Swift Package Manager 기반 CLI이므로 표준 루트 구조(`Package.swift` + `Sources/` + `Tests/`)를 유지한다.
- `project/`로 한 번 더 감싸면 SwiftPM 기본 규칙을 깨고 불필요한 경로 설정만 늘어난다.
- iOS 산출물은 bos 저장소 안이 아니라 `--project-root` 대상 폴더에 생성된다.

## Docs
- [Product Guide](./docs/PRODUCT_GUIDE.md)
- [Implementation Plan](./docs/IMPLEMENTATION-PLAN.md)
- [Tasks](./docs/TASKS.md)

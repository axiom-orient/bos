# Product Guide

## 1) Input Contract
`plan`의 기본 입력은 `PLAN/` 문서 폴더입니다.

단일 경로(권장):
- `--plan-dir <path>` + `--app-identifier` + `--apple-team-id`
- profile은 `.bos/config/profile.yaml` 기본 경로를 사용하고, 필요시 `--profile <path>`로 override

자동 추출 규칙:
- `FR-001` -> `REQ-001`
- 화면 키워드(`Today`, `Shelf`, `Capture`, `Focus`, `Reflection`, `Weekly Review`, `Settings`, `Permission+Voice`) -> `SCR_...`
- 도메인 heading(`11.1 Item`, `2.3 FocusSession`) -> `Entity`

PRD 직접 입력(`--prd`)도 지원하며, 이 경우 아래 마커를 그대로 읽습니다.

- `Project:`
- `App Identifier:`
- `Apple Team ID:`
- `REQ-...`
- `SCR_...`
- `Entity:`

예시:

```md
# PRD

Project: Daycraft
App Identifier: com.axiomorient.daycraft
Apple Team ID: A1B2C3D4E5

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

스킴 결정 규칙(단일):
- 우선: `Projects/App/Project.swift`의 `appName`
- fallback: `profile.name`을 PascalCase로 정규화 후 `App` suffix

## 3-1) Doctor Policy
- `--project-root` 생략 시 현재 터미널 경로(CWD)를 검사한다.
- `doctor`는 toolchain lock을 정책으로 해석한다.
  - `exact`: 완전 일치
  - `semver-range`: 범위 일치(예: `>=6.0 <7.0`)
- `requiredFor`에 포함된 명령만 blocking 판정한다.
  - 예: `fastlane`이 `release-init`에만 required면 `--for core` 검사에서는 권고(recommended)만 출력
- `--for`로 검사 범위를 선택한다.
  - `core`(기본): `plan/apply/verify`
  - `all`: `plan/apply/verify/release-init`
  - 개별: `plan|apply|verify|release-init`
- `--install`: 누락 도구의 설치 명령을 자동 실행 시도(명시 opt-in)
- `--init-lock`: lock이 없을 때 `.bos/config/toolchain.lock.yaml` 초기 생성

## 4) Artifact Policy
- 프로젝트 루트에는 로그/임시 JSON을 남기지 않음
- 모든 실행 아티팩트는 `/Users/axient/repository/bos/temp/<command>/<run-id>/` 하위에 on-demand 생성

## 5) Lock/State Path Policy
- 루트 단순화를 위해 lock/state/plan 파일은 `.bos/` 아래에만 둔다.
- 경로:
  - `.bos/config/toolchain.lock.yaml`
  - `.bos/config/profile.yaml`
  - `.bos/plan/blueprint.yaml`
  - `.bos/state/bos.state.yaml`
- `doctor`는 신규 경로를 우선 사용하고, 레거시 `toolchain.lock.yaml`은 fallback으로만 읽는다.
- `verify`/`release-init` 결과는 `.bos/state/bos.state.yaml`의 summary 필드에 동기화된다.
- 루트에는 `prd.md`, `profile.yaml`를 두지 않는 것을 기본 정책으로 한다.

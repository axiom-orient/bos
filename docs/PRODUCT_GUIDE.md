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
- `--for` 생략 시 기본 scope는 `release-init`이다.
- `requiredFor`에 포함된 명령만 blocking 판정한다.
  - 예: `fastlane`이 `release-init`에만 required면 `--for core` 검사에서는 권고(recommended)만 출력
- `--for`로 검사 범위를 선택한다.
  - `release-init`(기본)
  - `core`: `plan/apply/verify`
  - `all`: `plan/apply/verify/release-init`
  - 개별: `plan|apply|verify|release-init`
- 누락 required 도구 자동 설치를 기본으로 수행한다.
- lock 파일 없으면 자동 생성 (`config/toolchain.lock.yaml`)
- lock 경로는 `config/toolchain.lock.yaml`만 지원(`.bos/config/toolchain.lock.yaml` 미지원)
- signing env 파일 `.bos/config/signing.env`를 자동 로드한다(동일 키의 비어있지 않은 shell env가 우선).
- signing env 파일이 없으면 템플릿을 자동 생성한다.
- signing env 템플릿은 owner-only 권한(`0600`)으로 생성/보정한다.
- fastlane 설치는 `brew install fastlane` 단일 경로를 사용한다.
  - `brew`가 없으면 Homebrew 설치 스크립트를 먼저 실행한다.
  - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- `--for release-init` 또는 `--for all`에서는 signing env preflight를 추가로 수행한다.
  - 필수 키: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8_BASE64`, `MATCH_GIT_URL`, `MATCH_PASSWORD`
  - 형식 규칙: `ASC_ISSUER_ID`(UUID), `ASC_KEY_ID`(대문자/숫자 10자리), `ASC_KEY_P8_BASE64`(base64), `MATCH_GIT_URL`(git/https/ssh)

## 4) Artifact Policy
- 프로젝트 루트에는 로그/임시 JSON을 남기지 않음
- 모든 실행 아티팩트는 `<project-root>/.bos/artifacts/<command>/` 하위에 on-demand 생성

## 5) Lock/State Path Policy
- lock/state/plan 파일은 역할별로 분리한다.
- 경로:
  - `config/toolchain.lock.yaml`
  - `.bos/config/signing.env`
  - `.bos/plan/blueprint.yaml`
  - `.bos/state/bos.state.yaml`
- profile 기본 경로:
  - `.bos/config/profile.yaml`
- `verify`/`release-init` 결과는 `.bos/state/bos.state.yaml`의 summary 필드에 동기화된다.
- 루트에는 `prd.md`, `profile.yaml`를 두지 않는 것을 기본 정책으로 한다.

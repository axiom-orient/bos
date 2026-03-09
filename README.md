# bos

`bos` is a Swift CLI for bootstrapping and operating iOS projects with one consistent flow:

`plan -> apply -> verify -> app-register -> release-init -> release-check -> release-run`

It is designed to automate setup, validation, and release operations, not app feature development itself.

## Overview

- Generate a project blueprint from `PLAN/` markdown or a PRD.
- Scaffold a Tuist/TMA-based iOS project idempotently.
- Run smoke build/test verification without requiring debug provisioning profiles.
- Register Bundle ID and App Store Connect app records with `app-register`.
- Prepare fastlane scaffolding with `release-init`.
- Validate release readiness with live App Store Connect and `match` checks via `release-check`.
- Build, upload, and submit signed IPAs with `release-run`.
- Keep app onboarding metadata in one non-secret SSOT: `.bos/config/profile.yaml`.

## Quick Start

### Prerequisites

- Xcode 16+
- Swift 6+
- Tuist 4.x
- fastlane 2.228+
- `xcode-select` pointing to full Xcode for `doctor --for core` and `verify`

### Build From Source

```bash
swift build -c release
```

### Happy Path

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
bos doctor --for app-register
bos app-register
bos doctor --for release-init
bos release-init
bos doctor --for release-check
bos release-check
bos doctor --for release-run
bos release-run --stage beta
```

## Architecture

`bos` has a simple split:

- CLI surface: argument parsing, output formatting, command routing
- Core engines: pure command behavior for planning, generation, verification, onboarding, and release
- Resources/templates: bootstrap guides and Tuist/TMA project templates
- Runtime state/artifacts: `.bos/state/` and `.bos/artifacts/`

See [Architecture](./docs/ARCHITECTURE.md) for the full map.

## Core Modules

| Area | Responsibility | Main Files |
|---|---|---|
| CLI | command parsing, exit codes, JSON/human output | [`Sources/BosCLI/main.swift`](/Users/axient/repository/bos/Sources/BosCLI/main.swift) |
| Planning | `PLAN/` or PRD to blueprint generation | [`Sources/BosCore/PlanEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/PlanEngine.swift) |
| Scaffolding | Tuist/TMA project generation and drift control | [`Sources/BosCore/ApplyEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ApplyEngine.swift) |
| Verification | `tuist` + `xcodebuild` smoke gate | [`Sources/BosCore/VerifyEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/VerifyEngine.swift) |
| Onboarding | App Store Connect registration and metadata resolution | [`Sources/BosCore/AppRegistrationEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/AppRegistrationEngine.swift) |
| Release Prep | fastlane scaffold generation | [`Sources/BosCore/ReleaseInitEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseInitEngine.swift) |
| Release Readiness | live ASC auth, `match` repo, cert fetch/sync checks | [`Sources/BosCore/ReleaseCheckEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseCheckEngine.swift) |
| Release Execution | signed IPA build/upload/submit wrapper | [`Sources/BosCore/ReleaseRunEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseRunEngine.swift) |
| Policy/Schema | profile, blueprint, toolchain, signing rules | [`Sources/BosCore/Schemas.swift`](/Users/axient/repository/bos/Sources/BosCore/Schemas.swift), [`Sources/BosCore/SigningEnvironmentPolicy.swift`](/Users/axient/repository/bos/Sources/BosCore/SigningEnvironmentPolicy.swift) |

## Install / Run

### Core Commands

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
bos verify
bos app-register
bos release-init
bos release-check
bos release-run --stage build
```

### Xcode-Sensitive Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos doctor --for core
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

### Typical Release Commands

```bash
bos doctor --for app-register
bos app-register
bos doctor --for release-check
bos release-init
bos release-check
bos doctor --for release-run
bos release-run --stage release
```

## Usage Examples

### 1. Generate a Blueprint From `PLAN/`

```bash
bos plan --plan-dir ./PLAN --project-root /path/to/project
```

### 2. Scaffold a New Project

```bash
bos apply --project-root /path/to/project --mode init
```

### 3. Reconcile Managed Drift

```bash
bos apply --project-root /path/to/project --mode incremental --fix
```

### 4. Register an Existing or New App Record

```bash
bos app-register --project-root /path/to/project --format json
```

### 5. Read-Only Release Readiness Check

```bash
bos release-check --project-root /path/to/project --mode readonly-certs --format json
```

### 6. Signed IPA Build

```bash
bos release-run --project-root /path/to/project --stage build --format json
```

## Operations / Quality

### SSOT and Secrets

- Non-secret onboarding data lives in `.bos/config/profile.yaml`
  - `identity.companyName`
  - `identity.appName`
  - `identity.appIdentifier`
  - `identity.appleTeamId`
  - `release.primaryLanguage`
  - `release.sku`
  - `release.matchGitURL`
- Secrets live in `.bos/config/signing.env`
  - `ASC_ISSUER_ID`
  - `ASC_KEY_ID`
  - `ASC_KEY_P8_BASE64`
  - `MATCH_PASSWORD`

### Release Policy

- Default release validation is read-only.
- `release-check --mode sync-certs --allow-write` is an operational bootstrap for the first signing seed on an empty team/app setup.
- It is not a blocker for releasing the `bos` product itself.

### Artifacts and State

- Artifacts: `<project-root>/.bos/artifacts/<command>/`
- State summary: `<project-root>/.bos/state/bos.state.yaml`

### Quality Gates

```bash
swift test
swift build -c release
git diff --check
```

Current evidence on `codex/dev`:

- `swift test`: 98 tests in 13 suites passed
- `swift build -c release`: passed
- `git diff --check`: passed

## Constraints / Future Work

- `verify` still depends on a usable local Xcode developer directory.
- `release-check` and `release-run` depend on live Apple and `match` credentials.
- Multi-app workspace orchestration is intentionally out of scope for now.
- CI secret distribution remains an operational concern, not a built-in feature.

## Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [Product Guide](./docs/PRODUCT_GUIDE.md)
- [Testing Guide](./docs/TESTING_GUIDE.md)
- [Tests Overview](./Tests/README.md)

## Legacy Archive

- [Archived Implementation Plan](./docs/archive/IMPLEMENTATION-PLAN-2026-03-09.md)
- [Archived Tasks](./docs/archive/TASKS-2026-03-09.md)
- [Archived BOS Guide](./docs/archive/BOS_GUIDE-legacy.md)

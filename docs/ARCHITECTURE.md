# Architecture

## Overview

`bos` is a Swift Package Manager CLI with one executable target and one core library:

- CLI: [`Sources/BosCLI/main.swift`](/Users/axient/repository/bos/Sources/BosCLI/main.swift)
- Core library: [`Sources/BosCore/`](/Users/axient/repository/bos/Sources/BosCore)

The design is intentionally flat. Each command is routed by the CLI and handled by one focused engine in `BosCore`.

## System Context

### Primary User

- iOS engineer or automation agent setting up and operating an iOS project

### External Dependencies

- Xcode / `xcodebuild`
- Tuist
- fastlane
- App Store Connect API
- Git-hosted `match` repository

### Runtime Files

- Toolchain policy: `config/toolchain.lock.yaml`
- Onboarding SSOT: `.bos/config/profile.yaml`
- Signing secrets: `.bos/config/signing.env`
- Plan output: `.bos/plan/blueprint.yaml`
- State summary: `.bos/state/bos.state.yaml`
- Artifacts: `.bos/artifacts/<command>/`

## Command Flow

```mermaid
flowchart LR
  A["PLAN/ or PRD"] --> B["plan"]
  B --> C["blueprint.yaml"]
  C --> D["apply"]
  D --> E["Generated iOS project"]
  E --> F["verify"]
  F --> G["Smoke build/test evidence"]
  G --> H["app-register"]
  H --> I["ASC bundle ID / app record"]
  I --> J["release-init"]
  J --> K["Fastlane scaffold"]
  K --> L["release-check"]
  L --> M["Readiness evidence"]
  M --> N["release-run"]
  N --> O["IPA build/upload/submit"]
```

## Core Layers

### 1. CLI Layer

Responsibilities:

- Parse arguments
- Resolve default paths
- Load profile, blueprint, lock, and env files
- Convert engine results into human or JSON output
- Normalize exit codes

Main file:

- [`Sources/BosCLI/main.swift`](/Users/axient/repository/bos/Sources/BosCLI/main.swift)

### 2. Engine Layer

Each command owns one main engine.

| Command | Engine | Responsibility |
|---|---|---|
| `plan` | [`PlanEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/PlanEngine.swift) | Parse markdown input and emit blueprint data |
| `apply` | [`ApplyEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ApplyEngine.swift) | Generate scaffold and manage drift-safe updates |
| `verify` | [`VerifyEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/VerifyEngine.swift) | Run `tuist` + `xcodebuild` smoke validation |
| `app-register` | [`AppRegistrationEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/AppRegistrationEngine.swift) | Resolve onboarding metadata and register ASC resources |
| `release-init` | [`ReleaseInitEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseInitEngine.swift) | Generate fastlane scaffold and lane files |
| `release-check` | [`ReleaseCheckEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseCheckEngine.swift) | Validate release readiness against live external systems |
| `release-run` | [`ReleaseRunEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseRunEngine.swift) | Build/upload/submit signed artifacts |
| `doctor` | [`DoctorEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/DoctorEngine.swift) | Evaluate local toolchain policy and signing prerequisites |

### 3. Shared Policy / Schema Layer

Shared files define the command contract and runtime policy.

- [`Schemas.swift`](/Users/axient/repository/bos/Sources/BosCore/Schemas.swift): blueprint, profile, lock, and state schema
- [`OnboardingConfiguration.swift`](/Users/axient/repository/bos/Sources/BosCore/OnboardingConfiguration.swift): profile-driven onboarding defaults
- [`SigningEnvironmentPolicy.swift`](/Users/axient/repository/bos/Sources/BosCore/SigningEnvironmentPolicy.swift): ASC and signing env validation
- [`ProjectBuildSupport.swift`](/Users/axient/repository/bos/Sources/BosCore/ProjectBuildSupport.swift): scheme/workspace resolution and generated artifact cleanup
- [`BosStateStore.swift`](/Users/axient/repository/bos/Sources/BosCore/BosStateStore.swift): summary writes into `.bos/state/bos.state.yaml`
- [`CommandOutput.swift`](/Users/axient/repository/bos/Sources/BosCore/CommandOutput.swift): stable output payloads

### 4. Resource / Template Layer

- [`Sources/BosCore/Resources/project_bootstrap/`](/Users/axient/repository/bos/Sources/BosCore/Resources/project_bootstrap): copied bootstrap guides and rules
- [`Sources/BosCore/Resources/tma_plugin/`](/Users/axient/repository/bos/Sources/BosCore/Resources/tma_plugin): Tuist/TMA plugin resources

## Data Model

### Inputs

- Markdown planning corpus from `PLAN/`
- Optional PRD markers
- Optional onboarding overrides from CLI
- Profile SSOT from `.bos/config/profile.yaml`
- Signing secrets from `.bos/config/signing.env`

### Transformations

1. Planning text becomes blueprint data.
2. Blueprint plus profile becomes generated project structure.
3. Profile plus CLI overrides becomes onboarding metadata.
4. Environment plus profile becomes release-readiness context.

### Side Effects

- File generation under project root
- Artifact JSON/log writes
- State summary writes
- App Store Connect API calls
- `git ls-remote` against `match`
- fastlane lane execution

## Release Boundary

The release surface is intentionally split:

- `release-init`: local scaffold only
- `release-check`: live readiness evidence
- `release-run`: actual signed build/upload/submit

Important boundary:

- `readonly-certs` is the standard release-readiness path
- `sync-certs --allow-write` is only for first signing-seed bootstrap on an empty `match` setup
- That operational bootstrap is separate from the `bos` product release gate

## Quality Model

Automated quality is centered on integration tests rather than deep abstraction-heavy unit slices.

Current regression suite covers:

- schema validation
- CLI contract stability
- plan/apply/verify lifecycle
- onboarding metadata and ASC registration behavior
- release-check mode semantics
- release-run stage semantics

See [Testing Guide](./TESTING_GUIDE.md) and [Tests Overview](../Tests/README.md).

## Repository Layout

```text
bos/
├── Sources/
│   ├── BosCLI/
│   └── BosCore/
├── Tests/
│   ├── CoreTests/
│   └── Fixtures/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PRODUCT_GUIDE.md
│   ├── TESTING_GUIDE.md
│   └── archive/
├── Package.swift
└── README.md
```

## Constraints

- The product assumes SwiftPM standard layout and avoids extra wrapper folders.
- Full `verify` depends on a real Xcode developer directory.
- Release commands depend on external Apple and Git systems.
- Multi-app orchestration is intentionally not built into the first product surface.

# Architecture

## Overview

`bos` is a Swift Package Manager CLI with one executable target and one core library:

- CLI: [`Sources/BosCLI/`](/Users/axient/repository/bos/Sources/BosCLI)
- Core library: [`Sources/BosCore/`](/Users/axient/repository/bos/Sources/BosCore)

The design is intentionally flat. `BosCLI` now keeps dispatch, shared support, and each command entry in separate files, while each command is still handled by one focused engine in `BosCore`.

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

CLI files:

- [`main.swift`](/Users/axient/repository/bos/Sources/BosCLI/main.swift): entrypoint and command dispatch
- [`CLIModels.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIModels.swift): exit codes, command enums, and JSON payload types
- [`CLIParsing.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIParsing.swift): help text and option parsing
- [`CLICommandContext.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLICommandContext.swift): project-root/profile/blueprint/signing context loading
- [`CLIPathSupport.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIPathSupport.swift): project-root, profile, blueprint, and toolchain path helpers
- [`CLIConfigSupport.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIConfigSupport.swift): profile templates, signing env parsing, YAML encode/decode, and config file IO
- [`CLIProcessSupport.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIProcessSupport.swift): process execution, version detection, and engine runner adapters
- [`CLIOutputSupport.swift`](/Users/axient/repository/bos/Sources/BosCLI/CLIOutputSupport.swift): human/JSON rendering and terminal failure handling
- [`DoctorSupport.swift`](/Users/axient/repository/bos/Sources/BosCLI/DoctorSupport.swift): doctor-specific tool detection, toolchain lock setup, and auto-install support
- [`DoctorCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/DoctorCommand.swift): `doctor` adapter
- [`PlanCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/PlanCommand.swift): `plan` adapter
- [`ApplyCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/ApplyCommand.swift): `apply` adapter
- [`VerifyCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/VerifyCommand.swift): `verify` adapter
- [`ASCCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/ASCCommand.swift): raw `bos asc ...` adapter with BOS-managed env and artifacts
- [`AppRegisterCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/AppRegisterCommand.swift): `app-register` adapter
- [`ReleaseInitCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/ReleaseInitCommand.swift): `release-init` adapter
- [`ReleaseCheckCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/ReleaseCheckCommand.swift): `release-check` adapter
- [`ReleaseRunCommand.swift`](/Users/axient/repository/bos/Sources/BosCLI/ReleaseRunCommand.swift): `release-run` adapter

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
- [`ASCBackend.swift`](/Users/axient/repository/bos/Sources/BosCore/ASCBackend.swift): deterministic env-only `asc` execution bridge
- [`ASCAppStoreAppResolver.swift`](/Users/axient/repository/bos/Sources/BosCore/ASCAppStoreAppResolver.swift): bundle-ID-based App Store app ID resolution and profile backfill support
- [`ASCAppStoreReadinessChecker.swift`](/Users/axient/repository/bos/Sources/BosCore/ASCAppStoreReadinessChecker.swift): ASC-backed readiness/status checks for release flows
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
- Deterministic `asc` env bridge from BOS-managed inputs only

### Transformations

1. Planning text becomes blueprint data.
2. Blueprint plus profile becomes generated project structure.
3. Profile plus CLI overrides becomes onboarding metadata.
4. Profile plus `asc` lookup becomes canonical `appStoreAppId`.
5. Environment plus profile becomes release-readiness context.

### Side Effects

- File generation under project root
- Artifact JSON/log writes
- State summary writes
- App Store Connect API calls
- External `asc` CLI execution in env-only mode
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
- `app-register` still uses the native create path because deterministic API-key app creation is not yet provided by `asc`
- low-level ASC control is exposed through `bos asc ...`, not by re-implementing `asc` command families inside `bos`
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

See [Testing Guide](./TESTING_GUIDE.md).

## Repository Layout

```text
bos/
├── AGENTS.md
├── Sources/
│   ├── BosCLI/
│   │   ├── main.swift
│   │   ├── CLIModels.swift
│   │   ├── CLIParsing.swift
│   │   ├── CLICommandContext.swift
│   │   ├── CLIPathSupport.swift
│   │   ├── CLIConfigSupport.swift
│   │   ├── CLIProcessSupport.swift
│   │   ├── CLIOutputSupport.swift
│   │   ├── DoctorSupport.swift
│   │   ├── DoctorCommand.swift
│   │   ├── PlanCommand.swift
│   │   ├── ApplyCommand.swift
│   │   ├── VerifyCommand.swift
│   │   ├── AppRegisterCommand.swift
│   │   ├── ReleaseInitCommand.swift
│   │   ├── ReleaseCheckCommand.swift
│   │   └── ReleaseRunCommand.swift
│   └── BosCore/
├── Tests/
│   ├── CoreTests/
│   └── Fixtures/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── OPERATIONS_GUIDE.md
│   ├── PRODUCT_GUIDE.md
│   └── TESTING_GUIDE.md
├── Package.swift
└── README.md
```

## Constraints

- The product assumes SwiftPM standard layout and avoids extra wrapper folders.
- Full `verify` depends on a real Xcode developer directory.
- Release commands depend on external Apple and Git systems.
- Multi-app orchestration is intentionally not built into the first product surface.

# Testing Guide

## Overview

`bos` relies on integration-style regression tests.

The goal is to lock the user-visible contract:

- inputs
- command sequencing
- failure classification
- artifact output
- state synchronization

## Release Gates

```bash
swift test
swift build -c release
git diff --check
```

## Coverage Map

| Area | Test File | What It Locks |
|---|---|---|
| planning | [`PlanEngineIntegrationTests.swift`](../Tests/CoreTests/PlanEngineIntegrationTests.swift) | markdown extraction, metadata precedence, blueprint generation |
| scaffolding | [`ApplyEngineIntegrationTests.swift`](../Tests/CoreTests/ApplyEngineIntegrationTests.swift) | init/incremental generation, drift handling, idempotency |
| smoke verification | [`VerifyEngineIntegrationTests.swift`](../Tests/CoreTests/VerifyEngineIntegrationTests.swift) | command order, scheme resolution, signing suppression, cleanup, failure taxonomy |
| onboarding contract | [`AppRegistrationIntegrationTests.swift`](../Tests/CoreTests/AppRegistrationIntegrationTests.swift) | metadata resolution, deterministic SKU, profile backfill, env validation |
| ASC provider | [`NativeAppRegistrationProviderTests.swift`](../Tests/CoreTests/NativeAppRegistrationProviderTests.swift) | create path, race-to-existing path, provider failure propagation |
| release init | [`ReleaseInitEngineIntegrationTests.swift`](../Tests/CoreTests/ReleaseInitEngineIntegrationTests.swift) | fastlane scaffold generation and signing preflight |
| release readiness | [`ReleaseCheckEngineIntegrationTests.swift`](../Tests/CoreTests/ReleaseCheckEngineIntegrationTests.swift) | mode semantics, external step ordering, redaction, state sync |
| release execution | [`ReleaseRunEngineIntegrationTests.swift`](../Tests/CoreTests/ReleaseRunEngineIntegrationTests.swift) | `build|beta|release|submit` semantics, signing mode choice, IPA path, failure mapping |
| screenshots workflow | [`ScreenshotsEngineIntegrationTests.swift`](../Tests/CoreTests/ScreenshotsEngineIntegrationTests.swift) | screenshot plan summary, raw capture materialization, export composition, and coverage validation |
| device workflow | [`DeviceEngineIntegrationTests.swift`](../Tests/CoreTests/DeviceEngineIntegrationTests.swift) | normalized inventory, register/install/launch/logs flow, and device doctor output |
| CLI contract | [`CLIJsonOutputIntegrationTests.swift`](../Tests/CoreTests/CLIJsonOutputIntegrationTests.swift) | parse failures, JSON payload stability, profile/signing template behavior, doctor scope behavior |
| schemas/state | [`SchemaValidationTests.swift`](../Tests/CoreTests/SchemaValidationTests.swift) | strict schema decode, metadata/screenshot contract validation, and additive state fields |
| integrity guards | [`RepositoryIntegrityTests.swift`](../Tests/CoreTests/RepositoryIntegrityTests.swift) | markdown link health, packaged resource drift, repo-portable docs contracts |

## Practical Rules

- `doctor --for core` and `verify` depend on a full Xcode developer directory.
- `verify` suppresses debug signing so smoke validation does not depend on provisioning profiles.
- `release-init` is local scaffold generation only.
- `release-check` is the live release-readiness gate.
- `release-run` is the signed build/upload/submit wrapper.
- `release-check --mode sync-certs --allow-write` is operational bootstrap, not the default product release gate.

## Useful Commands

### Full Regression

```bash
swift test
swift build -c release
```

### Focused Suites

```bash
swift test --filter CLIJsonOutputIntegrationTests
swift test --filter DeviceEngineIntegrationTests
swift test --filter ScreenshotsEngineIntegrationTests
swift test --filter ReleaseCheckEngineIntegrationTests
swift test --filter ReleaseRunEngineIntegrationTests
swift test --filter RepositoryIntegrityTests
swift test --filter NativeAppRegistrationProviderTests
```

### Xcode-Sensitive Checks

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos doctor --for core
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

## Related Docs

- [README](../README.md)
- [Product Guide](../docs/PRODUCT_GUIDE.md)
- [Operations Guide](../docs/OPERATIONS_GUIDE.md)
- [Architecture](../docs/ARCHITECTURE.md)

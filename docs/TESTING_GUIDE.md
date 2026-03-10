# Testing Guide

## Overview

The `bos` test strategy is centered on integration-style regression tests.

The goal is not to unit-test every helper in isolation. The goal is to lock the command contract:

- inputs
- command sequencing
- failure classification
- artifact output
- state synchronization

## Current Quality Gates

```bash
swift test
swift build -c release
git diff --check
```

Verified locally:

- `swift test`: 100 tests in 13 suites passed
- `swift build -c release`: passed
- `git diff --check`: passed

## Test Map

| Area | Test File | What It Locks |
|---|---|---|
| planning | [`Tests/CoreTests/PlanEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/PlanEngineIntegrationTests.swift) | markdown extraction, metadata precedence, blueprint generation |
| scaffolding | [`Tests/CoreTests/ApplyEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/ApplyEngineIntegrationTests.swift) | init/incremental generation, drift handling, idempotency |
| smoke verification | [`Tests/CoreTests/VerifyEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/VerifyEngineIntegrationTests.swift) | command order, scheme resolution, signing suppression, cleanup, failure taxonomy |
| onboarding contract | [`Tests/CoreTests/AppRegistrationIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/AppRegistrationIntegrationTests.swift) | metadata resolution, deterministic SKU, profile backfill, env validation |
| ASC provider | [`Tests/CoreTests/NativeAppRegistrationProviderTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/NativeAppRegistrationProviderTests.swift) | create path, race-to-existing path, provider failure propagation |
| release init | [`Tests/CoreTests/ReleaseInitEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/ReleaseInitEngineIntegrationTests.swift) | fastlane scaffold generation and signing preflight |
| release readiness | [`Tests/CoreTests/ReleaseCheckEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/ReleaseCheckEngineIntegrationTests.swift) | mode semantics, external step ordering, redaction, state sync |
| release execution | [`Tests/CoreTests/ReleaseRunEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/ReleaseRunEngineIntegrationTests.swift) | `build|beta|release|submit` semantics, signing mode choice, IPA path, failure mapping |
| CLI contract | [`Tests/CoreTests/CLIJsonOutputIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/CLIJsonOutputIntegrationTests.swift) | parse failures, JSON payload stability, fallback paths, doctor scope behavior |
| schemas/state | [`Tests/CoreTests/SchemaValidationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/SchemaValidationTests.swift) | strict schema decode and additive state fields |

## Why `swift-testing` Matters

`CoreTests` explicitly depends on `swift-testing` in `Package.swift`.

That avoids environment-sensitive failures such as `no such module 'Testing'`.

## Xcode-Sensitive Commands

`doctor --for core` and `verify` depend on a full Xcode developer directory.

Use:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos doctor --for core
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

## Release Validation Strategy

### Product Release Gate

The product release gate is:

- automated regression
- release build success
- read-only live evidence for App Store Connect and `match`
- idempotent live onboarding evidence for `app-register`
- early signing-team mismatch detection during cert-based `release-check` modes

### Operational Bootstrap

This is intentionally separate:

```bash
bos release-check --mode sync-certs --allow-write
```

That command performs a writable external side effect and is used only when a team/app needs its first signing seed on an empty setup. It is not required to declare the `bos` product itself releasable.

## Recommended Verification Commands

### Full Regression

```bash
swift test
swift build -c release
```

### Command-Focused Checks

```bash
swift test --filter CLIJsonOutputIntegrationTests
swift test --filter ReleaseCheckEngineIntegrationTests
swift test --filter ReleaseRunEngineIntegrationTests
swift test --filter NativeAppRegistrationProviderTests
```

### Live, Read-Only Release Readiness

```bash
bos doctor --for app-register
bos app-register --format json
bos doctor --for release-check
bos release-init
bos release-check --mode readonly-certs --format json
```

## Practical Notes

- `doctor` default scope is `core`
- `doctor` only creates signing env templates for release-related scopes
- `verify` suppresses debug signing so scaffold smoke tests do not depend on provisioning profiles
- `release-init` is local scaffold generation only
- `release-check` is the live release-readiness gate
- `release-run` is the actual signed build/upload/submit wrapper

## Related Docs

- [README](../README.md)
- [Architecture](./ARCHITECTURE.md)
- [Product Guide](./PRODUCT_GUIDE.md)
- [Tests Overview](../Tests/README.md)

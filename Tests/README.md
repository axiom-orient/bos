# Tests Overview

## Purpose

The `bos` test suite verifies that the CLI contract remains stable across the full project lifecycle:

- plan
- apply
- verify
- app-register
- release-init
- release-check
- release-run
- doctor

This suite is intentionally integration-heavy. It prioritizes user-visible behavior over microscopic helper coverage.

## How To Run

```bash
swift test
swift build -c release
```

Focused runs:

```bash
swift test --filter AppRegistrationIntegrationTests
swift test --filter NativeAppRegistrationProviderTests
swift test --filter ReleaseCheckEngineIntegrationTests
swift test --filter ReleaseRunEngineIntegrationTests
swift test --filter CLIJsonOutputIntegrationTests
```

## Scenario Matrix

| Scenario | Locked By |
|---|---|
| Markdown planning to blueprint | [`CoreTests/PlanEngineIntegrationTests.swift`](./CoreTests/PlanEngineIntegrationTests.swift) |
| Scaffold generation and drift control | [`CoreTests/ApplyEngineIntegrationTests.swift`](./CoreTests/ApplyEngineIntegrationTests.swift) |
| Smoke build/test verification | [`CoreTests/VerifyEngineIntegrationTests.swift`](./CoreTests/VerifyEngineIntegrationTests.swift) |
| Toolchain and signing prerequisite checks | [`CoreTests/DoctorEngineIntegrationTests.swift`](./CoreTests/DoctorEngineIntegrationTests.swift), [`CoreTests/CLIJsonOutputIntegrationTests.swift`](./CoreTests/CLIJsonOutputIntegrationTests.swift) |
| App Store Connect metadata resolution | [`CoreTests/AppRegistrationIntegrationTests.swift`](./CoreTests/AppRegistrationIntegrationTests.swift) |
| Native ASC provider create/error behavior | [`CoreTests/NativeAppRegistrationProviderTests.swift`](./CoreTests/NativeAppRegistrationProviderTests.swift) |
| Fastlane scaffold generation | [`CoreTests/ReleaseInitEngineIntegrationTests.swift`](./CoreTests/ReleaseInitEngineIntegrationTests.swift) |
| Live release-readiness semantics | [`CoreTests/ReleaseCheckEngineIntegrationTests.swift`](./CoreTests/ReleaseCheckEngineIntegrationTests.swift) |
| Signed release execution semantics | [`CoreTests/ReleaseRunEngineIntegrationTests.swift`](./CoreTests/ReleaseRunEngineIntegrationTests.swift) |
| Schema strictness and state evolution | [`CoreTests/SchemaValidationTests.swift`](./CoreTests/SchemaValidationTests.swift) |

## File-by-File Intent

| Test File | Intent |
|---|---|
| [`CoreTests/PlanEngineIntegrationTests.swift`](./CoreTests/PlanEngineIntegrationTests.swift) | blueprint extraction and metadata precedence |
| [`CoreTests/ApplyEngineIntegrationTests.swift`](./CoreTests/ApplyEngineIntegrationTests.swift) | scaffold creation, idempotency, managed drift rules |
| [`CoreTests/VerifyEngineIntegrationTests.swift`](./CoreTests/VerifyEngineIntegrationTests.swift) | verify pipeline order, failure codes, workspace cleanup |
| [`CoreTests/AppRegistrationIntegrationTests.swift`](./CoreTests/AppRegistrationIntegrationTests.swift) | onboarding metadata resolution and profile sync |
| [`CoreTests/NativeAppRegistrationProviderTests.swift`](./CoreTests/NativeAppRegistrationProviderTests.swift) | Bundle ID/app create path, race handling, provider error path |
| [`CoreTests/ReleaseInitEngineIntegrationTests.swift`](./CoreTests/ReleaseInitEngineIntegrationTests.swift) | fastlane scaffold and signing preflight |
| [`CoreTests/ReleaseCheckEngineIntegrationTests.swift`](./CoreTests/ReleaseCheckEngineIntegrationTests.swift) | release-check mode contract, signing-team validation, redaction, state summary |
| [`CoreTests/ReleaseRunEngineIntegrationTests.swift`](./CoreTests/ReleaseRunEngineIntegrationTests.swift) | `build|beta|release|submit` stage contract |
| [`CoreTests/CLIJsonOutputIntegrationTests.swift`](./CoreTests/CLIJsonOutputIntegrationTests.swift) | CLI parse/JSON surface stability |
| [`CoreTests/SchemaValidationTests.swift`](./CoreTests/SchemaValidationTests.swift) | strict schema behavior |
| [`CoreTests/ProfilePolicyE2ETests.swift`](./CoreTests/ProfilePolicyE2ETests.swift) | fixture-backed apply+verify end-to-end regression |
| [`CoreTests/RuntimeArtifactsTests.swift`](./CoreTests/RuntimeArtifactsTests.swift) | artifact retention behavior |

## Notes

- `swift-testing` is an explicit dependency of `CoreTests`
- `verify` tests assume debug signing suppression
- `release-check --mode sync-certs --allow-write` is treated as an operational bootstrap, not as a required product release gate

## Related Docs

- [README](../README.md)
- [Architecture](../docs/ARCHITECTURE.md)
- [Product Guide](../docs/PRODUCT_GUIDE.md)
- [Testing Guide](../docs/TESTING_GUIDE.md)

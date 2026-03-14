# Test Matrix

## Purpose

Document the minimum compatibility matrix BOS v2 expects for local execution and CI release gates.

## Toolchain Matrix

| Concern | Supported window | Evidence source |
|---|---|---|
| Swift | `>=6.0 <7.0` | `config/toolchain.lock.yaml` |
| Xcode | `>=16.0 <17.0` | `config/toolchain.lock.yaml` |
| Tuist | `>=4.0 <5.0` | `config/toolchain.lock.yaml` |
| Ruby | `>=3.0 <4.0` | `config/toolchain.lock.yaml` |
| Bundler | `>=2.0 <3.0` | `config/toolchain.lock.yaml` |
| Node | `>=20.0 <23.0` | `config/toolchain.lock.yaml` |
| fastlane | `>=2.0 <3.0` | `config/toolchain.lock.yaml` |
| asc | `>=0.1.0` | `config/toolchain.lock.yaml` |
| devicectl | `present` | `config/toolchain.lock.yaml` |
| simctl | `present` | `config/toolchain.lock.yaml` |

## Required CI Gates

- `swift test`
- `swift build -c release`
- `git diff --check`
- docs link and policy integrity checks via `RepositoryIntegrityTests`
- packaged resource drift checks via `RepositoryIntegrityTests`

## Domain Coverage

- Metadata: `MetadataEngineIntegrationTests`
- Screenshots: `ScreenshotsEngineIntegrationTests`
- Device: `DeviceEngineIntegrationTests`
- Release hardening: `ReleaseRunEngineIntegrationTests` and `ReleaseCheckEngineIntegrationTests`

## Fresh-Clone Expectation

The supported fresh-machine path must succeed using canonical v2 inputs only:

- `bos.project.yaml`
- `config/bos.profile.yaml`
- `config/blueprint.lock.yaml`
- `config/screenshots.plan.yaml`
- `.bos/secrets/signing.env`

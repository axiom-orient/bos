# Target Architecture

## Design principles

1. **single-app first**
2. **commit-safe inputs outside `.bos/`**
3. **`.bos/` means ephemeral or secret**
4. **BOS owns contracts, not external ecosystems**
5. **every external call becomes a structured artifact**
6. **all workflows are resumable and idempotent where possible**
7. **CLI JSON output is a first-class API**
8. **all policy has a schema and version**

## Canonical file model v2

### Commit-safe, reviewable

- `PLAN/**`
- `config/toolchain.lock.yaml`
- `config/bos.profile.yaml`
- `config/blueprint.lock.yaml`
- `config/release.policy.yaml`
- `config/screenshots.plan.yaml`
- `metadata/**`

### Local secret / runtime

- `.bos/secrets/signing.env`
- `.bos/state/bos.state.yaml`
- `.bos/artifacts/**`
- `.bos/cache/**`

## Why this path model is better

It resolves the current semantic collision where `.bos/` contains both “safe to commit SSOT” and “do not commit runtime output”.

## Module layout

```text
Sources/
  BosCLI/
    Commands/
    Parsing/
    Output/
    Context/
  BosCore/
    Domain/
      Blueprint/
      Profile/
      Release/
      AppStore/
      Device/
      Screenshots/
      Runtime/
    Adapters/
      ASC/
      Fastlane/
      Tuist/
      Xcode/
      DeviceCtl/
      Simulator/
      Screenshots/
    Support/
      Files/
      YAML/
      JSON/
      Redaction/
      Logging/
      Compatibility/
```

## Owned workflow vs wrapped surface

### BOS fully owns

- plan to blueprint lock
- scaffold drift policy
- verify policy
- release stage sequencing
- artifact layout
- state transitions
- error classification
- secret redaction

### BOS wraps but does not reimplement

- raw App Store Connect surface
- certificate/profile synchronization internals
- Xcode archive/export internals
- simulator and physical device primitives
- screenshot composition engine internals

## Adapter contract

Every adapter returns a normalized result:

```yaml
command: asc
startedAt: 2026-03-13T00:00:00Z
finishedAt: 2026-03-13T00:00:02Z
exitCode: 0
classification: success
inputs:
  sanitized: true
artifacts:
  - .bos/artifacts/asc/run.json
  - .bos/artifacts/asc/stdout.log
  - .bos/artifacts/asc/stderr.log
```

## State machine

```text
uninitialized
  -> planned
  -> scaffolded
  -> verified
  -> app_registered
  -> release_scaffolded
  -> release_ready
  -> built
  -> beta_uploaded
  -> submitted
```

State must be derivable from artifacts plus current inputs, not only from one mutable file.

## New bounded contexts

### App Store / Metadata

Own:
- metadata pull/diff/push contract
- localization directory contract
- validation

Wrap:
- `asc` app/version/localization/media APIs

### Screenshots / Media

Own:
- screenshot plan schema
- capture matrix
- export validation
- artifact manifests

Wrap:
- screenshot generation or composition engine
- simulator capture toolchain

### Device / Simulator

Own:
- inventory model
- device registry sync contract
- install/launch/log collection contract

Wrap:
- `xcrun devicectl`
- simulator CLI
- Xcode build/run

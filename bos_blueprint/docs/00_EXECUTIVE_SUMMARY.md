# Executive Summary

## Final position

`bos` should **not** become a second `asc`, a second `fastlane`, or a second `Tuist`.
It should become a **deterministic orchestration kernel** for one app repository.

That means BOS should own only five things:

1. **stable local contracts**
   - profile
   - blueprint lock
   - release policy
   - screenshot plan
   - runtime state
2. **workflow orchestration**
   - bootstrap
   - verify
   - register
   - release readiness
   - release execution
3. **policy and safety**
   - required inputs
   - secret boundaries
   - redaction
   - idempotency
   - drift detection
4. **artifact normalization**
   - structured JSON
   - logs
   - manifests
   - resumable state
5. **adapter boundaries**
   - Tuist/TMA for project generation
   - `asc` for App Store Connect surface
   - fastlane/match for signing sync
   - Xcode/xcodebuild/devicectl/simctl for Apple toolchain and device work
   - screenshot generator for media creation

## What the current repo already gets right

- Product scope is intentionally narrow.
- Runtime files and operator flows are already documented.
- `asc` is wrapped instead of reimplemented.
- `release-init`, `release-check`, and `release-run` are separate stages.
- Tests focus on contract stability, not abstraction theater.
- Secrets and artifacts are treated separately.

## What must change first

### 1. Resolve commit-safe vs runtime-path confusion
Current docs say `profile.yaml` is safe to commit, but the current `.gitignore` ignores it. Current docs also make blueprint the primary generated input, while `.gitignore` ignores the default blueprint path.

**Recommendation:** move all commit-safe inputs out of `.bos/`.

### 2. Split the schema monolith
`Schemas.swift` is too central. It is acceptable for v1, but it will become the main maintenance bottleneck once metadata, screenshots, device operations, and migrations are added.

### 3. Separate “owned workflow” from “wrapped external surface”
BOS should expose a few guided workflows, while leaving raw `asc` pass-through available.

### 4. Add a physical-device and screenshot domain explicitly
“iPhone management” is not the same thing as App Store Connect management.
Those must be modeled as separate bounded contexts.

### 5. Upgrade the compatibility contract
The current toolchain policy is incomplete for the future product. It needs explicit Xcode, Ruby/Bundler, Node, and device tooling policy.

## Non-goals for the best version of BOS

- app feature implementation
- long-lived secret storage
- full reimplementation of App Store Connect API families
- generalized multi-app orchestration in v1
- replacing Xcode project/build tooling
- automatic legal/privacy truth generation

## Recommended product shape

### BOS v2 identity

> “Single-app iOS operations kernel with deterministic local contracts and thin, testable adapters around Apple and ecosystem tooling.”

### Primary domains

- Planning / Blueprint
- Project Scaffold
- Verification
- Identity / Signing
- App Store / Metadata
- Screenshots / Media
- Device / Simulator
- Release / Distribution
- Runtime / Artifacts / State

## Highest-priority immediate fixes

1. fix broken absolute links in markdown docs
2. resolve `.bos/config/profile.yaml` commit policy contradiction
3. resolve `.bos/plan/blueprint.yaml` lock-file contradiction
4. align `Mintfile` with current release versioning
5. extend toolchain lock to match actual release stages
6. add a root manifest and migration strategy
7. split schema file by domain
8. add contract tests for external adapter versions

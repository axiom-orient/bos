# Release Operations Know-How

## Purpose

This note captures the real problems that surfaced while onboarding and signing `Aether`, the exact fixes that worked, and the operating model that avoids repeating the same work for another app or another machine.

Use it as an operations note, not as a product contract. Product contracts stay in [README](../README.md), [Product Guide](./PRODUCT_GUIDE.md), and [Architecture](./ARCHITECTURE.md).

## What Actually Broke

### 1. App Store Connect identity and signing identity drifted apart

Observed evidence:

- `Aether` profile now resolves to `appleTeamId: 7WR76382QB` in `.bos/config/profile.yaml`.
- Real signing sync installed `Apple Distribution: Axient Inc. (7WR76382QB)` and `match AppStore com.axiomorient.aether`.
- The live `release-check` log still showed the team configured for sync as `8GT6LT258Y` before the fix.

Evidence:

- [`/Users/axient/repository/Aether/.bos/config/profile.yaml`](/Users/axient/repository/Aether/.bos/config/profile.yaml)
- [`/Users/axient/repository/Aether/.bos/artifacts/release-check/release-check-20260309144015.log`](/Users/axient/repository/Aether/.bos/artifacts/release-check/release-check-20260309144015.log)

Root cause:

- Bundle ID, App Store app record, project files, and signing assets were not driven from one verified team identity.

Exact fix:

- Move non-secret release identity into one SSOT: `.bos/config/profile.yaml`
- Align `blueprint`, generated project files, and release scaffold to the same `appleTeamId`

Prevention rule:

- Before the first signed build, treat `release-check --mode sync-certs --allow-write` as the source of truth for the actual signing team and compare it against profile/project config.

### 2. Release export was not deterministic

Observed evidence:

- Archive reached the export step, then failed because export options did not carry a provisioning profile mapping.
- `build_app` now emits explicit `export_options` with `provisioningProfiles[bundle_id] = "match AppStore <bundle_id>"`.

Evidence:

- [`/Users/axient/repository/Aether/.bos/artifacts/release-run/release-run-20260309144406.log`](/Users/axient/repository/Aether/.bos/artifacts/release-run/release-run-20260309144406.log)
- [`/Users/axient/repository/bos/Sources/BosCore/ReleaseInitEngine.swift`](/Users/axient/repository/bos/Sources/BosCore/ReleaseInitEngine.swift)

Root cause:

- `fastlane build_app` was allowed to infer export behavior instead of receiving an explicit App Store export map.

Exact fix:

- Generate `release_export_options`
- Pass `export_method: "app-store"`
- Pass `export_options: release_export_options`

Prevention rule:

- Release export must always be explicit. Do not rely on automatic export inference for distribution builds.

### 3. Release target signing was still too implicit

Observed evidence:

- The app template now pins release signing to `Manual`, `Apple Distribution`, and `match AppStore <bundle_id>`.
- Regression tests now lock this output.

Evidence:

- [`/Users/axient/repository/bos/Sources/BosCore/Resources/tma_plugin/Templates/app/Project.stencil`](/Users/axient/repository/bos/Sources/BosCore/Resources/tma_plugin/Templates/app/Project.stencil)
- [`/Users/axient/repository/bos/Tests/CoreTests/ApplyEngineIntegrationTests.swift`](/Users/axient/repository/bos/Tests/CoreTests/ApplyEngineIntegrationTests.swift)

Root cause:

- The smoke path and the release path were clear, but the release target still depended on Xcode signing inference.

Exact fix:

- Keep debug signing suppressed for `verify`
- Pin release signing to manual App Store distribution in the generated app target

Prevention rule:

- `verify` and release signing must stay separate. Smoke validation should not require provisioning profiles, but release export must always specify them.

### 4. The process still depends on `login.keychain`

Observed evidence:

- The live signing sync used `keychain_name = login.keychain`.
- The user experienced repeated keychain password prompts during real signing work.

Evidence:

- [`/Users/axient/repository/Aether/.bos/artifacts/release-check/release-check-20260309144015.log`](/Users/axient/repository/Aether/.bos/artifacts/release-check/release-check-20260309144015.log)

Root cause:

- Fastlane defaulted to the interactive login keychain, which is fragile for repeated automation and for a second machine.

Exact fix:

- No productized fix yet.
- Current stable workaround is to keep the signing environment correct and accept the interactive prompt on the login keychain path.

Prevention rule:

- Treat keychain prompts as an external machine/runtime condition, not as a `bos` product surface.

## Best Operating Model

### Team-level invariants

- Use one Team API key, not an individual key.
- Use one private `match` repository per Apple team or security boundary.
- Keep non-secret metadata in `.bos/config/profile.yaml`.
- Keep only secrets in `.bos/config/signing.env`.
- Reuse the same `MATCH_PASSWORD` for the same team repo until you intentionally rotate it.

Why:

- Current `bos` contract requires `ASC_ISSUER_ID`, so the stable path is a Team API key.
- `MATCH_GIT_URL` belongs to team/app operations metadata, not to secret material.

Evidence:

- [`/Users/axient/repository/bos/Sources/BosCore/SigningEnvironmentPolicy.swift`](/Users/axient/repository/bos/Sources/BosCore/SigningEnvironmentPolicy.swift)
- [`/Users/axient/repository/bos/Sources/BosCore/OnboardingConfiguration.swift`](/Users/axient/repository/bos/Sources/BosCore/OnboardingConfiguration.swift)

### New app bootstrap

For a new app, the minimum stable sequence is:

1. Fill `.bos/config/profile.yaml`
2. Fill `.bos/config/signing.env`
3. Run `bos app-register`
4. Run `bos release-init`
5. Run `bos release-check --mode sync-certs --allow-write` once
6. Run `bos release-run --stage build`

Why this order:

- `app-register` makes app identity idempotent.
- `release-init` makes the local release scaffold deterministic.
- `sync-certs` is the one-time first signing seed.
- `release-run --stage build` proves signed archive and IPA export, not just credential reachability.

### New machine bootstrap

For a second Mac, the stable goal is not to recreate the release configuration. The goal is to hydrate the same configuration.

Use the same:

- `.bos/config/profile.yaml`
- Team API key material
- `MATCH_PASSWORD`
- `match` repository

Then run:

```bash
bos doctor --for release-check
bos release-init
bos release-check --mode readonly-certs
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos release-run --stage build
```

If the machine has never synced signing assets before, do one explicit bootstrap:

```bash
bos release-check --mode sync-certs --allow-write
```

## Recommended Defaults For Future Apps

- `profile.yaml` is the only non-secret SSOT
- `signing.env` holds only secrets
- Team API key only
- one private `match` repo per team/security boundary
- read-only release checks by default
- writable signing sync only once per new team/app setup
- signed IPA build as the real release proof

## The Practical Rule

Do not optimize around “making the command shorter” first.

Optimize around making these five facts impossible to drift:

1. bundle identifier
2. Apple team ID
3. App Store app record
4. `match` repository
5. provisioning profile mapping at export time

If those five stay deterministic, the same app can be rebuilt on another machine without replaying the entire debugging process.

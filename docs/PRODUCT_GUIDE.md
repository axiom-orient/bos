# Product Guide

## Overview

`bos` is an operations CLI for iOS project bootstrap and release workflows.

Its public surface is intentionally narrow:

- `doctor`
- `plan`
- `apply`
- `verify`
- `app-register`
- `release-init`
- `release-check`
- `release-run`

The product goal is simple: turn setup and release operations into a repeatable CLI contract.

## Input Contract

### Preferred Inputs

- planning documents under `PLAN/`
- onboarding SSOT at `.bos/config/profile.yaml`
- signing secrets at `.bos/config/signing.env`

### Metadata Precedence

`CLI override > profile.yaml > blueprint/PRD marker > deterministic default`

### SSOT Fields

`.bos/config/profile.yaml`

- `identity.companyName`
- `identity.appName`
- `identity.appIdentifier`
- `identity.appleTeamId`
- `release.primaryLanguage`
- `release.sku`
- `release.matchGitURL`

`.bos/config/signing.env`

- `ASC_ISSUER_ID`
- `ASC_KEY_ID`
- `ASC_KEY_P8_BASE64`
- `MATCH_PASSWORD`

## Command Contracts

### `doctor`

Purpose:

- validate local toolchain and signing prerequisites

Default scope:

- `core`

Other scopes:

- `all`
- `plan|apply|verify|app-register|release-init|release-check|release-run`

Notes:

- creates `config/toolchain.lock.yaml` when missing
- creates `.bos/config/signing.env` template only for release-related scopes
- treats legacy `schemaVersion: 1` toolchain lock as unsupported

### `plan`

Purpose:

- convert markdown planning input into `.bos/plan/blueprint.yaml`

Supported inputs:

- `--plan-dir <path>`
- `--prd <path>`

Required extracted concepts:

- requirements
- screens
- entities

### `apply`

Purpose:

- generate or reconcile Tuist/TMA-based scaffold

Modes:

- `init`
- `incremental`

Rules:

- existing files are preserved
- managed drift can be fixed with `--fix`
- unmanaged changes fail hard

### `verify`

Purpose:

- run smoke validation for generated iOS projects

Pipeline:

1. `tuist install`
2. `tuist generate --no-open`
3. `xcodebuild build`
4. `xcodebuild test`

Important rule:

- debug signing is suppressed for the smoke path, so early verification does not require a provisioning profile

### `app-register`

Purpose:

- idempotently create or confirm Bundle ID and App Store Connect app record

Resolved metadata:

- `appIdentifier`
- `appleTeamId`
- `appName`
- `primaryLanguage`
- `sku`
- optional `companyName`
- optional `matchGitURL`

Behavior:

- returns `existing` when a resource already exists
- returns `created` when a resource is newly created
- syncs resolved metadata back into profile output

### `release-init`

Purpose:

- generate fastlane scaffold and required lanes

Output:

- `fastlane/Fastfile`
- `fastlane/Appfile`
- `fastlane/Matchfile`

### `release-check`

Purpose:

- validate live release readiness

Modes:

- `connectivity`
- `readonly-certs`
- `sync-certs`

Mode semantics:

- `connectivity`: ASC auth + `match` repo reachability
- `readonly-certs`: connectivity + read-only cert fetch + installed signing team validation
- `sync-certs`: connectivity + writable cert sync + installed signing team validation

Boundary:

- `sync-certs` requires explicit `--allow-write`
- `sync-certs` is an operational bootstrap for the first signing seed on an empty setup
- product release readiness is decided by read-only live evidence plus automated regression, not by forcing a writable external side effect
- if cert sync succeeds but the discovered signing team differs from `profile.identity.appleTeamId`, `release-check` fails early at `cert-sync`

### `release-run`

Purpose:

- execute signed IPA build/upload/submit from one bos-owned command

Stages:

- `build`
- `beta`
- `release`
- `submit`

Internal pipeline:

1. ensure scaffold with `release-init`
2. run `release-check`
3. run `tuist install/generate`
4. run fastlane build
5. optionally upload or submit depending on stage

## Standard User Flows

### Flow A. New Project

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

### Flow B. App Store Connect Onboarding

```bash
bos doctor --for app-register
bos app-register
```

### Flow C. Release Preparation

```bash
bos doctor --for release-init
bos release-init
bos doctor --for release-check
bos release-check
```

### Flow D. Signed Distribution

```bash
bos doctor --for release-run
bos release-run --stage build
bos release-run --stage beta
```

## Artifact and State Policy

Artifacts:

- `<project-root>/.bos/artifacts/app-register/`
- `<project-root>/.bos/artifacts/release-check/`
- `<project-root>/.bos/artifacts/release-run/`
- `<project-root>/.bos/artifacts/verify/`

State:

- `<project-root>/.bos/state/bos.state.yaml`

The product avoids leaving logs or temp JSON at repository root.

## Operating Rules

- Use `.bos/config/profile.yaml` as the only non-secret SSOT.
- Keep `MATCH_GIT_URL` in profile, not in `signing.env`.
- Use `readonly-certs` as the default operational path.
- Use `sync-certs` only when a new team/app needs its first signing seed.
- Prefer `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` over changing global `xcode-select` when verifying.

## Constraints

- `primaryLanguage` currently supports `en-US` and `ko-KR`
- release operations depend on live Apple and Git systems
- CI secret orchestration is outside the first product scope
- multi-app workspace orchestration is outside the first product scope

## Related Docs

- [README](../README.md)
- [Architecture](./ARCHITECTURE.md)
- [Testing Guide](./TESTING_GUIDE.md)

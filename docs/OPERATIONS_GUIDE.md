# Operations Guide

## Purpose

Use this document when you are operating `bos` against a real app project.

This guide answers only four things:

- which files must exist
- how those files appear
- what minimal values they need
- which order to run commands in

## Required Runtime Files

| Path | Purpose | How it appears |
|---|---|---|
| `.bos/config/profile.yaml` | non-secret onboarding SSOT | auto-created on first profile-using command |
| `.bos/config/signing.env` | signing and App Store Connect secrets | auto-created by release-scoped commands |
| `.bos/plan/blueprint.yaml` | generated scaffold and release input | created by `bos plan` or passed with `--blueprint` |
| `config/toolchain.lock.yaml` | local toolchain policy | created by `bos doctor` when missing |

Rules:

- `profile.yaml` is safe to commit.
- `signing.env` is secret and should not contain real values in git.
- `blueprint.yaml` is usually generated, not handwritten.
- the only default blueprint path is `.bos/plan/blueprint.yaml`.

## Minimal Reference Shapes

### `.bos/config/profile.yaml`

```yaml
# bos profile (safe to commit)
schemaVersion: 1
name: default
defaults:
  deploymentTarget: "18.0"
  appTargets:
    controlsExtension: false
    uiTests: true
identity:
  companyName: "Example Inc."
  appName: "Example App"
  appIdentifier: "com.example.app"
  appleTeamId: "A1B2C3D4E5"
release:
  primaryLanguage: "en-US"
  sku: "example.app.20260312"
  matchGitURL: "git@github.com:your-org/certificates.git"
featurePattern:
  sourcesInterface: true
  designFolder: false
rules:
  testingStyle: swift-testing
  forbidPatterns:
    - "@unchecked Sendable"
    - "Date()"
    - "UUID()"
```

Required fields for live onboarding or release:

- `identity.appName`
- `identity.appIdentifier`
- `identity.appleTeamId`
- `release.sku`
- `release.matchGitURL`

Commonly useful:

- `identity.companyName`
- `release.primaryLanguage`

### `.bos/config/signing.env`

```env
# bos signing environment (do not commit real values)
ASC_ISSUER_ID=123E4567-E89B-12D3-A456-426614174000
ASC_KEY_ID=AB12CD34EF
ASC_KEY_P8_BASE64=BASE64_OF_AUTHKEY_P8
MATCH_PASSWORD=your-match-password
```

Value sources:

- `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8_BASE64`: App Store Connect API key
- `MATCH_PASSWORD`: password used by `fastlane match`

`MATCH_GIT_URL` does not belong here. Keep it in `profile.yaml`.

Convert `.p8` to base64:

```bash
base64 -i /path/to/AuthKey_AB12CD34EF.p8 | tr -d '\n'
```

### `.bos/plan/blueprint.yaml`

```yaml
schemaVersion: 1
project:
  name: Example
  bundleIdPrefix: com.example
  deploymentTarget: "18.0"
requirements:
  reqIds: ["REQ-001"]
  screens: ["SCR_HOME"]
modules:
  app:
    name: ExampleApp
  features: ["Root", "Home"]
  domains: ["User"]
  services: ["Auth"]
  shared: ["Core", "DesignSystem"]
wiring:
  rootFeature: Root
release:
  fastlane:
    appIdentifier: com.example.app
    appleTeamId: A1B2C3D4E5
    appName: Example App
    sku: example.app.20260312
    primaryLanguage: en-US
    companyName: Example Inc.
```

Use this as a reference shape only. In normal operation, create it with:

```bash
bos plan --plan-dir ./PLAN
```

## Standard Runbooks

### New Project Bootstrap

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

### App Store Connect Registration

```bash
bos doctor --for app-register
bos app-register --format json
```

### Release Preparation

```bash
bos doctor --for release-init
bos release-init --format json
bos doctor --for release-check
bos release-check --mode readonly-certs --format json
```

### Signed Build

```bash
bos doctor --for release-run
bos release-run --stage build --format json
```

## Validation Before Live Use

Run these in order:

```bash
bos doctor --for app-register --format json
bos doctor --for release-init --format json
bos doctor --for release-check --format json
```

If the target project does not have `.bos/plan/blueprint.yaml`, generate it first:

```bash
bos plan --plan-dir ./PLAN
```

## Failure Order

- If `doctor` fails, fix local tools or missing secrets first.
- If `plan` fails, fix planning input until `requirements`, `screens`, and `entities` can be extracted.
- If `apply` fails, fix blueprint or managed drift first.
- If `verify` fails, fix Tuist/Xcode generation before release work.
- If `app-register` fails, fix profile identity fields or App Store Connect credentials.
- If `release-check` fails, fix `match`, signing, or team mismatch before `release-run`.

## This Repository vs Real App Projects

This repository is the `bos` product repository, not a generated app project.

That means:

- `.bos/config/profile.yaml` and `.bos/config/signing.env` here are templates
- `.bos/plan/blueprint.yaml` does not exist by default here
- real onboarding and release validation must happen in the target app project

## Related Docs

- [README](/Users/axient/repository/bos/README.md)
- [Product Guide](/Users/axient/repository/bos/docs/PRODUCT_GUIDE.md)
- [Architecture](/Users/axient/repository/bos/docs/ARCHITECTURE.md)
- [Testing Guide](/Users/axient/repository/bos/docs/TESTING_GUIDE.md)

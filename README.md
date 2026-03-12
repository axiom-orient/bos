# bos

`bos` is a CLI for iOS project bootstrap and release operations.

It owns one narrow path:

1. turn `PLAN/` or a PRD into `.bos/plan/blueprint.yaml`
2. generate the project scaffold
3. verify the generated project
4. prepare release files
5. run signed release stages

## Quick Start

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

If you already have a blueprint, skip `plan` and pass `--blueprint` when needed.

## Runtime Files

| Path | Role | Type |
|---|---|---|
| `PLAN/` | planning input | human input |
| `.bos/plan/blueprint.yaml` | generated scaffold/release input | runtime metadata |
| `.bos/config/profile.yaml` | non-secret onboarding SSOT | runtime metadata |
| `.bos/config/signing.env` | signing and App Store Connect secrets | runtime metadata |
| `config/toolchain.lock.yaml` | local toolchain policy | runtime metadata |
| `.bos/state/bos.state.yaml` | last command summary | runtime state |
| `.bos/artifacts/` | logs and JSON outputs | runtime output |

Rules:

- The only default blueprint path is `.bos/plan/blueprint.yaml`.
- Keep `MATCH_GIT_URL` in `.bos/config/profile.yaml`, not in `signing.env`.
- Treat `.bos/artifacts/` as disposable runtime output, not as project documentation.

## Main Commands

| Command | Purpose |
|---|---|
| `bos doctor` | validate toolchain and release prerequisites |
| `bos plan` | generate `.bos/plan/blueprint.yaml` from planning input |
| `bos apply` | create or reconcile the managed project scaffold |
| `bos verify` | run Tuist and Xcode smoke validation |
| `bos app-register` | create or confirm App Store Connect app metadata |
| `bos release-init` | create fastlane scaffold |
| `bos release-check` | validate live release readiness |
| `bos release-run` | build, upload, or submit signed artifacts |

## Docs By Audience

- [AGENTS.md](/Users/axient/repository/bos/AGENTS.md): repo-specific agent reading order and required metadata
- [Product Guide](/Users/axient/repository/bos/docs/PRODUCT_GUIDE.md): public command contract
- [Operations Guide](/Users/axient/repository/bos/docs/OPERATIONS_GUIDE.md): operator runbook and file examples
- [Architecture](/Users/axient/repository/bos/docs/ARCHITECTURE.md): maintainer structure map
- [Testing Guide](/Users/axient/repository/bos/docs/TESTING_GUIDE.md): regression and release validation

## What `bos` Does Not Own

- app feature implementation
- CI secret provisioning
- multi-app orchestration
- long-term storage of runtime artifacts

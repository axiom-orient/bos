# bos

`bos` is a CLI for iOS project bootstrap and release operations.

It owns one narrow path:

1. turn `PLAN/` or a PRD into `config/blueprint.lock.yaml`
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
| `bos.project.yaml` | root sentinel and path registry | committed input |
| `config/blueprint.lock.yaml` | generated scaffold/release input | committed input |
| `config/bos.profile.yaml` | non-secret onboarding SSOT | committed input |
| `.bos/secrets/signing.env` | signing and App Store Connect secrets | local secret input |
| `config/toolchain.lock.yaml` | local toolchain policy | runtime metadata |
| `.bos/state/bos.state.yaml` | last command summary | runtime state |
| `.bos/artifacts/` | logs and JSON outputs | runtime output |

Rules:

- Canonical v2 inputs live outside `.bos/`.
- Legacy `.bos/config/profile.yaml` and `.bos/plan/blueprint.yaml` reads are compatibility behavior only.
- Keep `MATCH_GIT_URL` in `config/bos.profile.yaml`, not in `signing.env`.
- Treat `.bos/artifacts/` as disposable runtime output, not as project documentation.

## Main Commands

| Command | Purpose |
|---|---|
| `bos doctor` | validate toolchain and release prerequisites |
| `bos plan` | generate `config/blueprint.lock.yaml` from planning input |
| `bos apply` | create or reconcile the managed project scaffold |
| `bos verify` | run Tuist and Xcode smoke validation |
| `bos asc` | forward raw App Store Connect commands through BOS-managed context |
| `bos metadata` | round-trip localized App Store metadata under the BOS directory contract |
| `bos screenshots` | validate screenshot plans, generate raw captures, and compose exports |
| `bos device` | normalize simulator and physical-device workflows with stable JSON output |
| `bos app-register` | create or confirm App Store Connect app metadata |
| `bos release-init` | create fastlane scaffold |
| `bos release-check` | validate live release readiness |
| `bos release-run` | build, upload, or submit signed artifacts |

## Docs By Audience

- [AGENTS.md](AGENTS.md): repo-specific agent reading order and required metadata
- [Product Guide](docs/PRODUCT_GUIDE.md): public command contract
- [Operations Guide](docs/OPERATIONS_GUIDE.md): operator runbook and file examples
- [Architecture](docs/ARCHITECTURE.md): maintainer structure map
- [Testing Guide](docs/TESTING_GUIDE.md): regression and release validation
- [Screenshots Contract](docs/SCREENSHOTS_CONTRACT.md): screenshot plan and export workflow contract
- [Device Contract](docs/DEVICE_CONTRACT.md): simulator/physical-device workflow contract
- [Migration Completion Checklist](docs/MIGRATION_COMPLETION_CHECKLIST.md): canonical-only exit criteria
- [Working Learnings](docs/WORKING_LEARNINGS.md): short continuation notes for ongoing v2 work

## What `bos` Does Not Own

- app feature implementation
- CI secret provisioning
- multi-app orchestration
- long-term storage of runtime artifacts

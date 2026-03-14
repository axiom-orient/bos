# Capability Matrix

This matrix is the honesty layer for the current BOS product surface.

| Domain | Surface | Current status | Notes |
|---|---|---|---|
| `doctor` | `core`, `metadata`, `screenshots`, `device`, release scopes | stable | Scope coverage, JSON output, and toolchain lock are aligned to the current command surface. |
| `metadata` | pull/diff/push/validate | stable | Contracted directory rules and validation are implemented and regression-covered. |
| `screenshots` | `plan`, `compose`, `validate` | stable | Plan validation, export composition, and coverage checks are implemented with manifest evidence. |
| `screenshots` | `capture` | partial | Default runtime uses a real `simctl`-backed simulator adapter. Physical-device capture and locale/orientation automation are not implemented. |
| `device` | `list`, `install`, `launch` | partial | Default runtime is simulator-backed via `simctl`. `install` and `launch` boot listed shutdown simulators before execution. Non-simulator target IDs fail explicitly. |
| `device` | `register`, `logs` | unsupported | Commands return explicit unsupported failures in the current runtime. |
| `device` | `doctor` | partial | Checks simulator readiness and reports physical-device/runtime gaps truthfully. |
| `app-register` | Bundle ID + ASC app registration | stable | Native create path remains intentional; resolved `appStoreAppId` is synced back into profile SSOT. |
| `release-policy` | submit requirements, signing mode, automation, locales | stable (v1) | First-version fields now drive submit preflight and fastlane submit behavior. |
| `release` | `release-init`, `release-check`, `release-run` | stable | Release scaffold, readiness checks, resumable execution, and submit gates are regression-covered. |

Rules:

- Do not describe `screenshots` or `device` as full end-to-end physical-device automation today.
- Treat `partial` rows as implemented but intentionally bounded.
- When behavior changes, update this file in the same change.

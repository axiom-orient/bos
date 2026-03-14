# Compatibility Policy

## Purpose

Define the compatibility contract for the BOS v2 migration so path changes, file ownership, and fallback behavior are explicit before implementation expands the product surface.

## Migration Principles

1. Existing golden-path commands remain the operator-facing contract during migration.
2. Canonical commit-safe inputs move out of `.bos/`.
3. `.bos/` becomes runtime-only plus local secrets.
4. Legacy path reads are temporary compatibility behavior, not the long-term contract.
5. New writes go to canonical v2 paths once the path registry is active.

## Path Compatibility Matrix

| Concern | Canonical v2 path | Legacy compatibility path | Commit policy | Migration rule |
|---|---|---|---|---|
| Project sentinel | `bos.project.yaml` | none | committed | Required for v2 path discovery |
| Profile SSOT | `config/bos.profile.yaml` | `.bos/config/profile.yaml` | committed | Read legacy during compatibility window; write canonical path |
| Blueprint lock | `config/blueprint.lock.yaml` | `.bos/plan/blueprint.yaml` | committed | Read legacy during compatibility window; generate canonical path |
| Release policy | `config/release.policy.yaml` | none | committed | New v2-only file |
| Screenshot plan | `config/screenshots.plan.yaml` | none | committed | New v2-only file |
| Signing secrets | `.bos/secrets/signing.env` | `.bos/config/signing.env` | local only | Read legacy during compatibility window; write canonical secret path |
| Runtime state | `.bos/state/bos.state.yaml` | none | local only | Runtime-owned only |
| Runtime artifacts | `.bos/artifacts/**` | none | local only | Runtime-owned only |
| Runtime cache | `.bos/cache/**` | none | local only | Runtime-owned only |

## Compatibility Window

The migration uses one explicit compatibility window:

- Phase A
  - BOS reads canonical v2 paths first.
  - If canonical files are absent, BOS may read the documented legacy path.
  - BOS writes newly created profile, blueprint, and signing files only to canonical v2 paths.
- Phase B
  - BOS still reports legacy path usage clearly in human and JSON output when fallback is used.
  - Tests must cover both canonical-path and legacy-read behavior.
- Phase C
  - Once fresh-clone validation passes using only canonical v2 paths, legacy reads may be removed in a later cleanup task.

## Non-Negotiable Rules

- No commit-safe canonical file may live only under `.bos/` once the path registry is enabled.
- Secret files never move into `config/`.
- Runtime-generated artifacts never become canonical inputs.
- Compatibility behavior must be test-backed before docs are updated to claim it.

## Required Proof Before Leaving The Compatibility Window

- A fresh clone works with only `bos.project.yaml` and canonical v2 config files.
- CLI tests prove canonical-first resolution and legacy fallback behavior.
- `.gitignore` matches the documented commit policy.
- Docs and examples contain no legacy-only default paths unless explicitly labeled as migration behavior.

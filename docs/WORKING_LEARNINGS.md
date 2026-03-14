# Working Learnings

## Why This Exists

This file is the short reference for continuing BOS v2 work without re-learning the same constraints.

## Non-Negotiables

### 1. Path policy is already decided

- Commit-safe canonical inputs live outside `.bos/`.
- Use:
  - `bos.project.yaml`
  - `config/bos.profile.yaml`
  - `config/blueprint.lock.yaml`
- Keep secrets and runtime output under `.bos/`:
  - `.bos/secrets/signing.env`
  - `.bos/state/bos.state.yaml`
  - `.bos/artifacts/**`
- Legacy `.bos/config/profile.yaml`, `.bos/plan/blueprint.yaml`, `.bos/config/signing.env` are compatibility reads only.

### 2. `.bos/state` is derived state, not a source of truth

- Primary evidence lives in artifact bundles.
- State must summarize progress in a form that can be reconstructed from:
  - current inputs
  - latest artifact bundle
  - explicit completed/failed steps
- Do not add opaque mutable flags that cannot be explained by artifacts.

### 3. Every wrapped workflow should emit the same artifact contract

- Standard bundle:
  - `run.json`
  - `stdout.log`
  - `stderr.log`
  - `manifest.json`
- New command families should use the shared adapter writer before adding bespoke files.
- Artifacts are evidence first, not convenience logs.

### 4. Add domains in this order

Use this sequence for any new command family:

1. contract doc
2. schema/model
3. schema/integrity tests
4. engine implementation
5. CLI adapter and JSON output
6. artifact assertions

Skipping directly to CLI or external-tool calls causes drift fast.

## Practical Rules

### When changing docs

- Run link/integrity checks, not just manual review.
- A deleted source file should immediately imply doc link cleanup.

### When changing packaged resources

- Treat `Sources/BosCore/Resources/**` as shipped product assets.
- Verify bundle contents still mirror repository files.

### When touching release flows

- Keep failure classification explicit.
- Keep resumability conservative.
- Reuse existing IPA/build evidence only when the checkpoint is explicit and the artifact still exists.

### When touching secrets

- Redaction tests are mandatory whenever logs or adapter plumbing change.
- Never trust raw stdout/stderr to stay clean.

## Current Safe Extension Pattern

- Reuse shared path helpers.
- Reuse strict schema validation.
- Reuse adapter artifact bundles.
- Prefer fake-runner integration tests over brittle end-to-end live tests.
- Keep human output thin; keep JSON output stable.

## Stop Signs

Pause and re-check the design if a change:

- introduces another canonical path outside the agreed registry
- makes state the only place where progress is knowable
- adds a new artifact layout for one command family
- relies on undocumented external-tool behavior
- broadens public CLI surface before contract/tests exist

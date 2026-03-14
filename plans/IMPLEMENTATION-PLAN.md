# BOS v2 Alignment Implementation Plan

## Planning Goal

Create an execution-ready migration plan that moves `bos` from the current v1 runtime and path model to the v2 blueprint model while preserving the existing golden-path commands and keeping external integrations thin, testable, and deterministic.

## Scope

In scope:

- `bos_blueprint/**`
- `Sources/BosCLI/**`
- `Sources/BosCore/**`
- `Tests/CoreTests/**`
- `docs/**`
- `config/**`
- `.gitignore`
- New repository-level manifests and commit-safe config files required by the blueprint

Out of scope for the first critical path:

- Broadening the command surface before path, schema, and adapter contracts are stable
- Re-implementing external ecosystems already wrapped by `asc`, fastlane, Tuist, Xcode, or simulator/device tooling
- Product-level polish work that does not affect the migration-critical contract

## Inputs Reviewed

Repository contract inputs reviewed before planning:

- `docs/PRODUCT_GUIDE.md`
- `docs/ARCHITECTURE.md`
- `docs/TESTING_GUIDE.md`
- `README.md`
- `AGENTS.md`
- `config/toolchain.lock.yaml`
- `.gitignore`
- `.bos/config/profile.yaml`
- `.bos/config/signing.env`
- `.bos/artifacts/**`

Blueprint bundle reviewed in full:

- `bos_blueprint/README.md`
- `bos_blueprint/docs/00_EXECUTIVE_SUMMARY.md`
- `bos_blueprint/docs/01_FILE_BY_FILE_AUDIT.md`
- `bos_blueprint/docs/02_TARGET_ARCHITECTURE.md`
- `bos_blueprint/docs/03_COMMAND_SURFACE_V2.md`
- `bos_blueprint/docs/04_ROADMAP.md`
- `bos_blueprint/docs/05_IMPLEMENTATION_PLAN.md`
- `bos_blueprint/docs/06_REQUIRED_FILES.md`
- `bos_blueprint/docs/07_BACKLOG.md`
- `bos_blueprint/docs/adr/ADR-001-own-vs-wrap.md`
- `bos_blueprint/docs/adr/ADR-002-path-semantics.md`
- `bos_blueprint/docs/adr/ADR-003-testing-strategy.md`
- `bos_blueprint/examples/*`

Implementation hotspots reviewed in `Sources/`:

- CLI path, config, parsing, and context loaders
- `PlanEngine`, `ApplyEngine`, `VerifyEngine`
- `DoctorEngine`, `ASCBackend`, `AppRegistrationEngine`
- `ReleaseInitEngine`, `ReleaseCheckEngine`, `ReleaseRunEngine`
- `Schemas.swift`, `RuntimeArtifacts.swift`, `BosStateStore.swift`
- Resource bundle contents under `Sources/BosCore/Resources/**`

## Current State Snapshot

### What is already aligned with the blueprint

- The public command surface is intentionally narrow and matches the v1 golden path.
- The repo already treats `asc` as a wrapped surface instead of re-implementing it.
- The release flow is already separated into `release-init`, `release-check`, and `release-run`.
- Integration-style tests already protect the user-facing contract better than abstraction-heavy unit slices would.
- Secrets, state, and artifacts are already modeled separately, even if the path semantics are not yet fully consistent.

### Current gaps that block safe v2 expansion

1. Path semantics are inconsistent.
   - Docs describe `.bos/config/profile.yaml` as commit-safe SSOT while `.gitignore` excludes it.
   - Docs and CLI defaults still point blueprint output to `.bos/plan/blueprint.yaml`.
   - Path constants are spread across `CLIPathSupport.swift`, `CLIConfigSupport.swift`, `PlanCommand.swift`, docs, and examples.

2. Schema ownership is too centralized.
   - `Sources/BosCore/Schemas.swift` currently carries blueprint, profile, toolchain lock, and bootstrap state concerns in one file.
   - This is tolerable for v1, but it becomes a hard bottleneck for metadata, screenshots, device state, and migration logic.

3. Adapter outputs are not standardized enough.
   - Commands generally emit one JSON file and one log file.
   - The blueprint requires a consistent adapter envelope and artifact manifest (`run.json`, `stdout.log`, `stderr.log`, `manifest.json`) across wrapped tools.
   - Repeated runner/result/log-writing patterns exist across verify, release, ASC, doctor, and app registration flows.

4. Engine files mix policy, IO, and orchestration.
   - `AppRegistrationEngine.swift`, `ReleaseCheckEngine.swift`, `ReleaseRunEngine.swift`, and `DoctorEngine.swift` already carry multiple responsibilities.
   - That accidental concentration will slow down safe additions unless contracts are extracted first.

5. Docs and examples are not yet migration-safe.
   - The repo still contains absolute local links.
   - The documented path model does not match the blueprint's `.bos is runtime-only` rule.

## Complexity Inventory

### Essential complexity

- Release staging across `release-init`, `release-check`, and `release-run`
  - The product must model preflight, readiness, and signed execution as separate stages.
- Secret-aware adapter boundaries
  - BOS must validate, curate, and redact external-tool environments before and after execution.
- Strict schemas for durable contracts
  - Profile, blueprint, toolchain lock, and state files are long-lived interfaces, not incidental structs.
- Drift-safe scaffold updates
  - `apply` must preserve managed boundaries and fail safely on out-of-band edits.

### Accidental complexity

- Scattered path policy
  - The same canonical locations are encoded in docs, CLI defaults, git policy, and templates separately.
- `Schemas.swift` monolith
  - Multiple unrelated domains change together and share one validation surface.
- Repeated process runner and artifact-writing patterns
  - Each command writes its own result payload shape instead of sharing one adapter envelope.
- Large mixed-responsibility engines
  - Metadata resolution, env validation, command execution, and artifact persistence are often combined in the same file.
- Documentation drift
  - Absolute links and path contradictions create review noise unrelated to the product domain.

### Simplification candidates ordered by removal value

1. Centralize path semantics and add a migration layer
   - Removes the largest cross-file contradiction and unlocks docs, git policy, and new config files.
2. Introduce one shared adapter result and artifact bundle writer
   - Removes repeated JSON/log plumbing and enables command-family growth without more divergence.
3. Split schema ownership by domain
   - Removes the primary structural bottleneck before metadata, screenshots, and device state are added.
4. Promote state to a derived resumable model
   - Removes hidden ambiguity from release restarts and makes artifacts first-class evidence.

## Assumptions

- The migration will be staged, not a flag-day rewrite.
- New canonical commit-safe files will live under `config/` and repository root, not under `.bos/`.
- `.bos/` will become runtime-only, but legacy reads will remain available for one compatibility window.
- New command families (`metadata`, `screenshots`, `device`) should start only after Phase 1 foundation work is complete.
- Existing golden-path commands and JSON output remain the compatibility anchor during migration.

## Done Condition

The migration program is complete when all of the following are true:

- All canonical commit-safe inputs are reviewable in git and no longer semantically depend on `.bos/`.
- The repo has one authoritative path registry and migration layer, with explicit fallback behavior covered by tests.
- Schema ownership is split by domain and legacy fixtures migrate without silent drift.
- All wrapped external-tool flows emit a standard artifact envelope with redacted outputs and manifest metadata.
- Release state is resumable and derivable from artifacts plus current inputs.
- Metadata, screenshots, and device domains each have bounded contracts, tests, and command surfaces consistent with the blueprint.
- Docs, examples, `.gitignore`, and CI all reflect the true runtime contract.

## Execution Strategy

### Phase 0 - Contract Repair and Migration Base

Goal:

- Make the current repo internally consistent before broadening scope.

Primary outputs:

- `bos.project.yaml`
- Central path registry and resolver
- New canonical commit-safe paths under `config/`
- Legacy path fallback behavior
- Updated docs, templates, and `.gitignore`
- Docs integrity and git policy checks

Why first:

- Every later domain depends on stable path semantics, clear commit policy, and a root sentinel.

Verification:

- New and legacy path resolution tests
- `git check-ignore` assertions
- docs link validation
- CLI JSON output coverage for old and new path shapes

### Phase 1 - Schema, Adapter, and State Foundation

Goal:

- Remove the core structural bottlenecks that would otherwise multiply complexity during v2 expansion.

Primary outputs:

- Domain-specific schema files
- Shared schema codec and migration layer
- Shared adapter result and artifact bundle writer
- Standard artifact envelope across existing command families
- Enriched state model with resumable release evidence

Why second:

- Metadata, screenshots, and device domains all need new schemas and adapter surfaces.
- Refactoring these after new domains land would cause avoidable churn and migration risk.

Verification:

- `SchemaValidationTests` extended for migration scenarios
- Command integration tests updated to assert standard artifact bundles
- Secret redaction and runtime artifact retention tests retained or expanded

### Phase 2 - Metadata and Screenshot Domains

Goal:

- Add the first new owned workflows without violating the "own workflows, wrap ecosystems" boundary.

Primary outputs:

- `metadata/` directory contract
- `bos metadata pull|diff|push|validate`
- `config/screenshots.plan.yaml`
- `bos screenshots plan|capture|compose|validate`

Why after Phase 1:

- These flows need new schemas, artifact manifests, and compatibility-aware adapters.

Verification:

- Metadata round-trip tests with locale coverage checks
- Screenshot plan validation tests
- Artifact manifest tests for capture and composition flows

### Phase 3 - Device Domain

Goal:

- Separate physical-device and simulator operations from App Store responsibilities.

Primary outputs:

- Device inventory model
- `bos device list|register|install|launch|logs|doctor`
- Simulator lifecycle and capture support

Verification:

- Fake-runner adapter tests
- Artifact output tests for device workflows
- Contract tests for device and simulator command normalization

### Phase 4 - Release Hardening

Goal:

- Make the release system resumable, diagnosable, and less ambiguous under failure.

Primary outputs:

- Explicit stage graph
- Resume manifests
- Finer failure taxonomy
- Staged evidence package for signed distribution

Verification:

- Release resume and restart tests
- Adapter fault-injection tests
- State-derivation tests from artifacts

### Phase 5 - Productization and Compatibility Policy

Goal:

- Turn the evolved repo contract into an enforceable public product surface.

Primary outputs:

- `docs/COMPATIBILITY_POLICY.md`
- `docs/STATE_MODEL.md`
- `docs/SECURITY_MODEL.md`
- `docs/TEMPLATE_VERSIONING.md`
- `docs/TEST_MATRIX.md`
- Resource checksum enforcement
- Compatibility-matrix CI jobs

Verification:

- CI matrix proves supported toolchain windows
- Docs and example validation remain green from a fresh clone

## Critical Path

`BOS-V2-001 Path policy -> BOS-V2-002 Root sentinel and path registry -> BOS-V2-003 Canonical config migration with fallback -> BOS-V2-004 Docs and git policy repair -> BOS-V2-006 Schema split -> BOS-V2-007 Schema/path migration layer -> BOS-V2-008 Adapter envelope -> BOS-V2-009 Existing command refactor -> BOS-V2-010 Resumable state model -> new domains`

This is the shortest safe path because it removes the repo-wide contradictions and shared bottlenecks before adding new command families.

## Decision Gates

| Gate | Check | Pass condition | On fail |
|---|---|---|---|
| Path semantics locked | Canonical file map, sentinel, fallback window, docs, and `.gitignore` all agree | All path tests pass and no commit-safe file lives only under `.bos/` | Stop feature expansion and resolve contract first |
| Schema split ready | Domain schemas and migration layer compile and decode legacy fixtures | `SchemaValidationTests` and migration fixtures pass with stable encoding | Do not add new config files or new domains |
| Adapter envelope stable | Wrapped commands emit one standard artifact bundle | Verify, ASC, app-register, release-init/check/run all produce normalized artifacts with redaction | Keep adapters local; do not broaden command surface |
| Resume model safe | State is derivable from artifacts and restart semantics are explicit | Release restart tests prove clean rerun or resume behavior | Do not market release hardening as complete |
| Domain contract approved | Metadata, screenshots, and device schemas plus JSON output are bounded and testable | Contract and compatibility tests exist before implementation broadens | Keep command family out of public surface |

## Verification Strategy

### Regression gates for every phase

- `swift test`
- `swift build -c release`
- `git diff --check`

### Phase-specific verification additions

- Phase 0
  - docs link checker
  - `git check-ignore` contract checks
  - CLI tests for old/new path resolution and sentinel behavior
- Phase 1
  - schema migration fixtures
  - artifact bundle assertions for every adapter-backed command
  - redaction and resource drift tests
- Phase 2
  - metadata round-trip tests
  - screenshot plan and export validation tests
- Phase 3
  - device adapter contract tests with fake runners
- Phase 4
  - resume and fault-injection tests
- Phase 5
  - compatibility matrix CI jobs across supported toolchain windows

## Open Edges

1. Legacy fallback lifetime is still a product decision.
   - Assumption used in this plan: keep legacy `.bos` reads for one compatibility window, but write new canonical files only to v2 paths.

2. The exact migration behavior for `bos plan` output needs one final product choice.
   - Assumption used in this plan: `config/blueprint.lock.yaml` becomes the canonical reviewable output, while legacy `.bos/plan/blueprint.yaml` remains a compatibility input during the transition.

3. Screenshot composition backend selection is not on the immediate critical path.
   - The contract can be planned now; the tool choice can stay deferred until Phase 2 starts.

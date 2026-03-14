# Template Versioning

## Purpose

Define how BOS version-tracks generated templates and packaged resources so scaffold changes remain reviewable and drift is caught in CI.

## Version Sources

- `config/toolchain.lock.yaml`
  - pins the current `tmaPluginRef`
- `Sources/BosCore/Resources/project_bootstrap/**`
  - repository-owned bootstrap templates copied into generated projects
- `Sources/BosCore/Resources/tma_plugin/**`
  - repository-owned plugin resources bundled with the BOS binary

## Policy

1. Template changes must be committed in the repository, never fetched dynamically at runtime.
2. `tmaPluginRef` is the compatibility anchor for the packaged plugin surface.
3. Template changes that affect generated output must land with regression coverage or updated golden expectations.
4. Packaged resource drift is a CI failure, not a release-time surprise.
5. Version bumps should prefer additive compatibility where possible; breaking scaffold moves must be called out in release notes and migration docs.

## Required Proof

- `RepositoryIntegrityTests` must fail if packaged resources drift from repository sources.
- `SchemaValidationTests` must continue to decode the current toolchain lock and plugin reference.
- `swift test` and `swift build -c release` remain required release gates after template changes.

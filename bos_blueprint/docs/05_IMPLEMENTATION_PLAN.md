# Implementation Plan

## Workstream A — Repository hygiene and contract repair

Tasks:
- replace absolute local links in all docs
- define one canonical version source
- resolve `.bos/` semantic split
- add `bos.project.yaml` root sentinel

Acceptance:
- a fresh clone renders docs correctly on GitHub
- `git check-ignore` matches documented semantics

## Workstream B — Schema decomposition

Tasks:
- split `Schemas.swift` into:
  - `BlueprintSchema.swift`
  - `ProfileSchema.swift`
  - `ReleasePolicySchema.swift`
  - `StateSchema.swift`
  - `ScreenshotPlanSchema.swift`
- add schemaVersion migration tests

Acceptance:
- old fixtures migrate cleanly
- JSON/YAML encoding remains stable

## Workstream C — Adapter standardization

Tasks:
- define one `ProcessAdapterResult`
- standardize artifact write layout
- wrap `asc`, fastlane, xcodebuild, devicectl, screenshot composer with same envelope

Acceptance:
- all commands emit `run.json`, `stdout.log`, `stderr.log`, `manifest.json`

## Workstream D — Metadata domain

Tasks:
- define `metadata/` directory layout
- implement pull/diff/push/validate
- add locale coverage checks

Acceptance:
- metadata can round-trip without semantic drift

## Workstream E — Screenshots domain

Tasks:
- define `config/screenshots.plan.yaml`
- define capture targets
- separate capture from composition
- validate dimensions and count

Acceptance:
- one command can prove required screenshots exist and are exportable

## Workstream F — Device domain

Tasks:
- device inventory model
- physical device registration sync
- install/launch/log collection
- simulator targeting and cleanup

Acceptance:
- connected device workflow is scriptable and artifacted

## Workstream G — Release hardening

Tasks:
- enrich release state
- support resume from artifacts
- add explicit stage graph
- classify external failures precisely

Acceptance:
- failed `release-run` can be resumed or cleanly re-run with no hidden ambiguity

## Workstream H — Testing and CI

Tasks:
- golden project fixtures
- docs link checks
- schema migration tests
- secret leak tests
- compatibility jobs by toolchain profile

Acceptance:
- CI proves both command contract and documentation integrity

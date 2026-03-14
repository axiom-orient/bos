# Backlog

## P0 — must do before broadening scope

- [ ] P0-001 Fix all absolute doc links
- [ ] P0-002 Resolve profile path contradiction
- [ ] P0-003 Resolve blueprint path contradiction
- [ ] P0-004 Align Mint/release version source
- [ ] P0-005 Add Xcode to toolchain lock
- [ ] P0-006 Add root manifest `bos.project.yaml`
- [ ] P0-007 Add docs integrity CI check

## P1 — current product hardening

- [ ] P1-001 Split `Schemas.swift`
- [ ] P1-002 Standardize adapter artifact manifest
- [ ] P1-003 Add schema migration tests
- [ ] P1-004 Add compatibility matrix for asc/tuist/fastlane/Xcode
- [ ] P1-005 Add resource checksum tests for bundled templates

## P2 — metadata domain

- [ ] P2-001 Define `metadata/` structure
- [ ] P2-002 Implement `bos metadata pull`
- [ ] P2-003 Implement `bos metadata diff`
- [ ] P2-004 Implement `bos metadata push`
- [ ] P2-005 Implement locale completeness validation

## P3 — screenshots domain

- [ ] P3-001 Define screenshot plan schema
- [ ] P3-002 Capture simulator matrix
- [ ] P3-003 Compose marketing slides
- [ ] P3-004 Validate export dimensions and count
- [ ] P3-005 Artifact package for submission

## P4 — device domain

- [ ] P4-001 Device inventory command
- [ ] P4-002 Developer portal device registration sync
- [ ] P4-003 Install/launch/log collection
- [ ] P4-004 Simulator lifecycle management
- [ ] P4-005 Device doctor and trust guidance

## P5 — release hardening

- [ ] P5-001 Resumable release manifests
- [ ] P5-002 Failure taxonomy refinement
- [ ] P5-003 Roll-forward / restart guidance
- [ ] P5-004 External adapter fault injection tests

## Definition of done for BOS v2

- one clean fresh-machine path works end-to-end
- all canonical inputs are reviewable in git
- all secrets remain outside git
- all external commands are artifacted and redacted
- JSON output is stable enough for other agents/tools

# ADR-003: Integration-first, compatibility-aware testing

## Decision

Keep integration-style testing as the primary quality model.
Add compatibility matrix and migration tests rather than over-abstracted unit slices.

## Required additions

- schema migration tests
- docs link tests
- adapter compatibility tests
- resource drift tests
- secret redaction tests

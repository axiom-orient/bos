# ADR-002: `.bos/` is runtime-only

## Decision

In v2, `.bos/` contains only ephemeral outputs and local secrets.
All commit-safe canonical inputs move under `config/` or `PLAN/`.

## Rationale

This removes semantic ambiguity and aligns git policy with human expectations.

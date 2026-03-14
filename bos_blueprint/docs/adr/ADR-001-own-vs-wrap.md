# ADR-001: Own workflows, wrap ecosystems

## Decision

BOS owns deterministic workflows and runtime contracts.
BOS wraps external tools for domain surfaces it should not fully reimplement.

## Consequence

Good:
- less duplication
- faster delivery
- easier ecosystem upgrades

Bad:
- adapter compatibility becomes critical
- external tool changes must be contract-tested

# Required Files to Add

## New repository files

```text
docs/ARCHITECTURE_V2.md
docs/STATE_MODEL.md
docs/SECURITY_MODEL.md
docs/COMPATIBILITY_POLICY.md
docs/TEMPLATE_VERSIONING.md
docs/TEST_MATRIX.md
docs/COMMAND_SURFACE_V2.md
docs/adr/ADR-001-own-vs-wrap.md
docs/adr/ADR-002-path-semantics.md
docs/adr/ADR-003-testing-strategy.md
config/bos.profile.yaml
config/blueprint.lock.yaml
config/release.policy.yaml
config/screenshots.plan.yaml
bos.project.yaml
metadata/README.md
```

## Required policies

### `bos.project.yaml`
Purpose:
- explicit root sentinel
- canonical path registry
- future migration anchor

### `config/bos.profile.yaml`
Purpose:
- commit-safe onboarding SSOT

### `config/blueprint.lock.yaml`
Purpose:
- reviewable generated lock input for deterministic scaffold

### `config/release.policy.yaml`
Purpose:
- explicit release policy instead of scattered assumptions

### `config/screenshots.plan.yaml`
Purpose:
- app-store screenshot intent, locales, device matrix, output requirements

## Strong recommendation

Do **not** keep commit-safe canonical files under `.bos/` in v2.

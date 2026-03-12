# AGENTS.md

## Read Order

Read these files in order when working in this repository:

1. [Product Guide](/Users/axient/repository/bos/docs/PRODUCT_GUIDE.md)
2. [Architecture](/Users/axient/repository/bos/docs/ARCHITECTURE.md)
3. [Testing Guide](/Users/axient/repository/bos/docs/TESTING_GUIDE.md)
4. [Operations Guide](/Users/axient/repository/bos/docs/OPERATIONS_GUIDE.md) only for onboarding or release work

## Required Runtime Metadata

These are not convenience docs. They are runtime inputs or outputs:

- `config/toolchain.lock.yaml`
- `.bos/config/profile.yaml`
- `.bos/config/signing.env`
- `.bos/plan/blueprint.yaml`
- `.bos/state/bos.state.yaml`
- `.bos/artifacts/<command>/`

Rules:

- Treat `.bos/artifacts/` as runtime output, not documentation.
- Treat `.bos/config/profile.yaml` as the only non-secret SSOT.
- Treat `.bos/config/signing.env` as secret input. Do not commit real values.
- Treat `.bos/plan/blueprint.yaml` as generated input. The only default path is `.bos/plan/blueprint.yaml`.

## Human-Facing Docs

- [README](/Users/axient/repository/bos/README.md): repository entrypoint
- [Product Guide](/Users/axient/repository/bos/docs/PRODUCT_GUIDE.md): public command contract
- [Operations Guide](/Users/axient/repository/bos/docs/OPERATIONS_GUIDE.md): operator runbook
- [Architecture](/Users/axient/repository/bos/docs/ARCHITECTURE.md): maintainer structure map
- [Testing Guide](/Users/axient/repository/bos/docs/TESTING_GUIDE.md): validation and release gate

## Product Assets, Not Repo Docs

These paths are shipped resources for generated app projects. Do not treat them as repository documentation:

- `Sources/BosCore/Resources/project_bootstrap/`
- `Sources/BosCore/Resources/tma_plugin/`

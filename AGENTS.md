# AGENTS.md

## Read Order

Read these files in order when working in this repository:

1. [Product Guide](docs/PRODUCT_GUIDE.md)
2. [Architecture](docs/ARCHITECTURE.md)
3. [Testing Guide](docs/TESTING_GUIDE.md)
4. [Operations Guide](docs/OPERATIONS_GUIDE.md) only for onboarding or release work

## Required Runtime Metadata

These are not convenience docs. They are runtime inputs or outputs:

- `config/toolchain.lock.yaml`
- `bos.project.yaml`
- `config/bos.profile.yaml`
- `.bos/secrets/signing.env`
- `config/blueprint.lock.yaml`
- `.bos/state/bos.state.yaml`
- `.bos/artifacts/<command>/`

Rules:

- Treat `.bos/artifacts/` as runtime output, not documentation.
- Treat `config/bos.profile.yaml` as the only non-secret SSOT.
- Treat `.bos/secrets/signing.env` as secret input. Do not commit real values.
- Treat `config/blueprint.lock.yaml` as the canonical generated input.
- Treat `.bos/config/profile.yaml`, `.bos/config/signing.env`, and `.bos/plan/blueprint.yaml` as legacy compatibility paths only.

## Human-Facing Docs

- [README](README.md): repository entrypoint
- [Product Guide](docs/PRODUCT_GUIDE.md): public command contract
- [Operations Guide](docs/OPERATIONS_GUIDE.md): operator runbook
- [Architecture](docs/ARCHITECTURE.md): maintainer structure map
- [Testing Guide](docs/TESTING_GUIDE.md): validation and release gate

## Product Assets, Not Repo Docs

These paths are shipped resources for generated app projects. Do not treat them as repository documentation:

- `Sources/BosCore/Resources/project_bootstrap/`
- `Sources/BosCore/Resources/tma_plugin/`

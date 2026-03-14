# Migration Completion Checklist

## Exit Criteria For BOS v2

- canonical v2 inputs are sufficient for the supported fresh-clone workflow
- legacy `.bos/config/profile.yaml`, `.bos/plan/blueprint.yaml`, and `.bos/config/signing.env` are compatibility reads only, not required setup
- metadata, screenshots, and device command families have contract docs, engines, and regression coverage
- release resume and evidence packaging are covered by regression tests
- compatibility policy, template versioning policy, and test matrix docs exist and remain linked from repo docs

## Fresh-Clone Path

The supported canonical-only path is:

1. `bos doctor`
2. `bos plan --prd ./PRD.md`
3. `bos apply --mode init`
4. `bos release-init`
5. `bos screenshots plan`
6. `bos device list`

Required canonical/runtime files:

- `bos.project.yaml`
- `config/bos.profile.yaml`
- `config/blueprint.lock.yaml`
- `config/screenshots.plan.yaml`
- `.bos/secrets/signing.env`

## Legacy Downgrade Rule

- legacy paths may still be read during the documented compatibility window
- no fresh-clone or documented happy path may require those legacy paths
- removal of legacy reads is a separate cleanup step after canonical-only validation remains green

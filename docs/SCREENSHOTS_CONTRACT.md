# Screenshots Contract

## Purpose

`config/screenshots.plan.yaml` defines BOS-owned screenshot intent before any simulator or device execution happens. It exists so `bos screenshots plan|capture|compose|validate` can share one reviewable contract for locale coverage, device matrix, export shape, and artifact layout.

## Plan Shape

```text
config/screenshots.plan.yaml
  schemaVersion
  defaultLocale
  locales[]
  devices[]
  shots[]
  export
```

Rules:

- `defaultLocale` must be one of `locales[].locale`.
- `locales[]` defines the localization matrix BOS must prove.
- `devices[]` defines the capture matrix and canonical export pixel size.
- `shots[]` binds app screens to locale and device coverage.
- `export.rootDirectory` is the committed output contract BOS will validate after composition.
- `export.format` is currently `png` only.

## Schema Fields

### `locales[]`

- `locale`: BCP-47 style value such as `en-US` or `ko-KR`
- `displayName`: human-readable label for reports

### `devices[]`

- `id`: stable plan-local identifier referenced by `shots[].devices`
- `name`: operator-facing device label
- `family`: `iphone | ipad`
- `platform`: `simulator | device`
- `orientation`: `portrait | landscape`
- `pixelSize.width`, `pixelSize.height`: required export dimensions

### `shots[]`

- `id`: stable screenshot identifier
- `screenID`: product screen or flow identifier
- `locales[]`: locale references from `locales[]`
- `devices[]`: device references from `devices[]`
- `launchArguments[]`: optional deterministic capture arguments
- `outputName`: base export name used by compose/validate

### `export`

- `rootDirectory`: final composed screenshot root
- `format`: currently `png`
- `includeFrame`: whether the composition contract expects framed exports

## Workflow Contract

All `bos screenshots` commands must support `--format human|json` and return stable top-level keys.

Current runtime reality:

- `plan`, `compose`, and `validate` are implemented and regression-covered.
- `capture` uses a real `simctl`-backed simulator adapter.
- `devices[].platform: device` is schema-valid but not executable in the current capture runtime.

### `bos screenshots plan`

Purpose:

- validate `config/screenshots.plan.yaml`
- summarize required locale/device/shot coverage before capture work starts

JSON payload fields:

- `command`
- `status`
- `summary`
- `planPath`
- `defaultLocale`
- `localeCount`
- `deviceCount`
- `shotCount`
- `artifacts`

### `bos screenshots capture`

Purpose:

- execute the capture matrix for the selected shots and locales
- materialize raw captures before composition

JSON payload fields:

- `command`
- `status`
- `summary`
- `capturedShots`
- `failedShots`
- `artifacts`

### `bos screenshots compose`

Purpose:

- transform raw captures into export-ready PNG outputs
- produce manifest evidence for every required shot/device/locale tuple

JSON payload fields:

- `command`
- `status`
- `summary`
- `outputDirectory`
- `composedFiles`
- `missingOutputs`
- `artifacts`

### `bos screenshots validate`

Purpose:

- prove required outputs exist and match the declared plan
- fail if locale/device/shot coverage is incomplete

JSON payload fields:

- `command`
- `status`
- `summary`
- `outputDirectory`
- `valid`
- `missingOutputs`
- `unexpectedFiles`
- `artifacts`

## Artifact Rules

- Every screenshots subcommand writes a normalized adapter bundle under `.bos/artifacts/screenshots-<subcommand>/`.
- `run.json`, `stdout.log`, `stderr.log`, and `manifest.json` remain the required artifact envelope.
- Capture and compose flows must record enough manifest detail to trace each generated file back to `shot`, `locale`, and `device`.

## Non-goals For This Contract Step

- physical-device screenshot capture
- locale-driving app orchestration beyond the plan matrix and raw simulator capture boundary
- choosing a second screenshot compositor backend
- defining video or animated preview assets
- mutating profile, blueprint, or metadata state during screenshot work

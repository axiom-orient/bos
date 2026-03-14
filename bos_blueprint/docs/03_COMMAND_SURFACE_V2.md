# Command Surface v2

## Keep current golden path stable

These commands remain and keep their mental model:

- `bos doctor`
- `bos plan`
- `bos apply`
- `bos verify`
- `bos asc`
- `bos app-register`
- `bos release-init`
- `bos release-check`
- `bos release-run`

## Add only three new command families

### 1. `bos metadata`

```bash
bos metadata pull
bos metadata diff
bos metadata push
bos metadata validate
```

Purpose:
- localize and version App Store metadata without inflating raw `asc` into BOS core

### 2. `bos screenshots`

```bash
bos screenshots plan
bos screenshots capture
bos screenshots compose
bos screenshots validate
```

Purpose:
- define required shots
- capture via simulator/device matrix
- compose/resize/export
- validate against Apple requirements

### 3. `bos device`

```bash
bos device list
bos device register
bos device install
bos device launch
bos device logs
bos device doctor
```

Purpose:
- physical iPhone and simulator management, clearly separated from App Store operations

## Commands intentionally not added in v2

- `bos testers`
- `bos analytics`
- `bos finances`
- `bos xcode-cloud`
- `bos subscription`

These stay behind raw `asc` or future adapters until the core path is fully hardened.

## Output contract

Every command must support:

```bash
--format human|json
```

JSON shape rules:
- stable top-level keys
- machine-readable failure classification
- artifact paths always returned
- no secrets in output
- deterministic key ordering in tests

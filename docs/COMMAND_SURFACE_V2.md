# Command Surface v2

## Keep The Current Golden Path Stable

These commands remain and keep their current mental model:

- `bos doctor`
- `bos plan`
- `bos apply`
- `bos verify`
- `bos asc`
- `bos app-register`
- `bos release-init`
- `bos release-check`
- `bos release-run`

## Add Only Three New Command Families

### `bos metadata`

```bash
bos metadata pull
bos metadata diff
bos metadata push
bos metadata validate
```

Purpose:

- own App Store metadata workflows without re-implementing raw ASC families inside BOS core
- contract: [`METADATA_CONTRACT.md`](./METADATA_CONTRACT.md)

### `bos screenshots`

```bash
bos screenshots plan
bos screenshots capture
bos screenshots compose
bos screenshots validate
```

Purpose:

- define screenshot intent, capture matrix, composition, and export validation as BOS-owned contracts
- contract: [`SCREENSHOTS_CONTRACT.md`](./SCREENSHOTS_CONTRACT.md)

### `bos device`

```bash
bos device list
bos device register
bos device install
bos device launch
bos device logs
bos device doctor
```

Purpose:

- separate physical-device and simulator management from App Store operations
- contract: [`DEVICE_CONTRACT.md`](./DEVICE_CONTRACT.md)

## Commands Intentionally Not Added In v2

- `bos testers`
- `bos analytics`
- `bos finances`
- `bos xcode-cloud`
- `bos subscription`

These remain outside the public BOS surface until the core path is hardened.

## Output Contract

Every command family must support:

```bash
--format human|json
```

JSON shape rules:

- stable top-level keys
- machine-readable failure classification
- artifact paths always returned
- no secrets in output
- deterministic key ordering in tests

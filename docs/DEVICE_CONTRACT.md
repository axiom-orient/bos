# Device Contract

## Purpose

`bos device` owns normalized device and simulator workflows without folding those responsibilities into App Store commands. It exists so physical-device and simulator operations can be scripted, artifacted, and reported with stable JSON output.

## Inventory Model

`DeviceInventory` is the bounded schema for normalized BOS device state.

Each record must include:

- `id`: stable device identifier
- `name`: operator-facing label
- `kind`: `simulator | physical`
- `platform`: platform name such as `iOS`
- `state`: normalized lifecycle state such as `booted`, `shutdown`, `connected`, `disconnected`
- `runtime`: simulator runtime when known
- `isAvailable`: whether BOS can currently target the device

Rules:

- Simulator and physical devices stay in the same inventory model, but the current default runtime only enumerates available simulators.
- `register` is reserved for future physical-device registration intent and does not succeed today.
- `install` and `launch` currently support simulator targets only, and the runtime will boot a listed shutdown simulator before executing them.
- `logs` is intentionally unsupported until BOS has a normalized process/log selection contract.
- `doctor` reports simulator readiness plus current physical-device/runtime gaps without overlapping release readiness semantics.

## Command Shape

All `bos device` commands must support `--format human|json` and return stable top-level keys.

Current runtime reality:

- `list` uses real `simctl` inventory for available simulators.
- `install` and `launch` use real `simctl` commands for simulator target IDs.
- if a listed simulator is still `shutdown`, BOS boots it and waits for `bootstatus -b` before `install` or `launch`.
- `register` and `logs` return explicit unsupported failures in the current runtime.
- physical-device execution paths are not implemented yet, even though the normalized schema keeps room for them.

### `bos device list`

Purpose:

- return the normalized BOS device inventory

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `devices`
- `artifacts`

### `bos device register`

Purpose:

- record or confirm physical-device registration intent for one device identifier

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `targetDevice`
- `artifacts`

### `bos device install`

Purpose:

- install an app bundle or app artifact onto a target device
- for simulator targets, boot a listed shutdown device first if needed

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `targetDevice`
- `appPath`
- `artifacts`

### `bos device launch`

Purpose:

- launch a bundle identifier on the target device
- for simulator targets, boot a listed shutdown device first if needed

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `targetDevice`
- `bundleIdentifier`
- `artifacts`

### `bos device logs`

Purpose:

- collect normalized log lines for one target device

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `targetDevice`
- `logLines`
- `artifacts`

### `bos device doctor`

Purpose:

- report device-workflow readiness without overlapping release checks

JSON payload fields:

- `command`
- `status`
- `summary`
- `subcommand`
- `findings`
- `artifacts`

## Artifact Rules

- Every device subcommand writes a normalized adapter bundle under `.bos/artifacts/device-<subcommand>/`.
- `run.json`, `stdout.log`, `stderr.log`, and `manifest.json` remain mandatory.
- Device list/register/install/launch/logs/doctor flows must keep their subcommand-specific payload stable enough for machine parsing.

## Non-goals For This Contract Step

- App Store Connect tester/device APIs
- screenshot capture orchestration
- release certificate or provisioning flows
- Xcode Cloud or CI device scheduling

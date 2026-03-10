# bos

`bos` is a command-line tool that turns a project plan into an iOS project setup and release flow.

What it does in order:

1. read your plan
2. create the project structure
3. check that it builds
4. prepare release files
5. help you build and upload the app

It is for project setup and release work. It does not write your app features for you.

## When To Use It

Use `bos` when you need to:

- turn `PLAN/` documents or a PRD into a project blueprint
- create a new iOS project structure from that blueprint
- update the generated project safely when the plan changes
- run a basic build/test check
- register the app in App Store Connect
- prepare release files
- build a signed IPA for TestFlight or App Store release

If a blueprint or plan is given, `bos` is meant to carry the project through setup, verification, and release preparation.

## What You Need Before Starting

- Xcode 16+
- Swift 6+
- Tuist 4.x
- fastlane 2.228+

For build and verification commands, use full Xcode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Quick Start

If you are starting from `PLAN/`, this is the main setup flow:

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

- `doctor`: checks whether your machine is ready
- `plan`: reads your planning documents and creates a blueprint
- `apply`: creates the project files
- `verify`: checks that the generated project can build and test

If these four commands pass, the basic project setup is complete.

If you already have a blueprint file, you can skip `plan` and start from `apply`.

## Typical Flows

### 1. Create a Project From a Plan

```bash
bos doctor
bos plan --plan-dir ./PLAN
bos apply --mode init
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

This is the default path for a new app.

### 2. Update an Existing Generated Project

```bash
bos plan --plan-dir ./PLAN
bos apply --mode incremental --fix
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bos verify
```

Use this when the plan changed and you want `bos` to update only the generated parts safely.

### 3. Register the App for Release

```bash
bos doctor --for app-register
bos app-register
```

This checks release account information and creates or confirms the app registration.

### 4. Prepare Release Files

```bash
bos doctor --for release-init
bos release-init
bos doctor --for release-check
bos release-check
```

This creates the release files and checks whether the release environment is ready.

### 5. Build a Signed App

```bash
bos doctor --for release-run
bos release-run --stage build
```

This creates a signed IPA file.

If you need upload or submission after the signed build:

```bash
bos release-run --stage beta
bos release-run --stage release
bos release-run --stage submit
```

## Main Commands

| Command | What it means in plain language |
|---|---|
| `bos doctor` | Check whether your machine and required tools are ready |
| `bos plan` | Read your plan and create a blueprint file |
| `bos apply` | Create or update the project files |
| `bos verify` | Make sure the generated project builds and tests |
| `bos app-register` | Create or confirm the app registration |
| `bos release-init` | Create the files needed for release work |
| `bos release-check` | Check whether release setup is actually ready |
| `bos release-run` | Build, upload, or submit the app |

## Important Files `bos` Uses

These are the main files and folders you will see:

- `PLAN/`
  - your planning documents
- `.bos/plan/blueprint.yaml`
  - the blueprint created from your plan
- `.bos/config/profile.yaml`
  - app information that is safe to keep in the project
- `.bos/config/signing.env`
  - release secrets
- `.bos/state/bos.state.yaml`
  - summary of the last important runs
- `.bos/artifacts/`
  - logs and output files from commands

The most important rule is simple:

- `PLAN/` is your input
- `.bos/plan/blueprint.yaml` is the generated setup plan
- `apply` turns that plan into the actual project files

Blueprint path rule:

- the supported default path is `.bos/plan/blueprint.yaml`
- if you keep a blueprint somewhere else, pass `--blueprint` explicitly

## Safe Defaults

`bos` tries to keep the early setup simple:

- `verify` does not require a debug provisioning profile
- normal release checks are read-only by default
- writable signing sync is used only for the first signing seed when needed

This keeps the common path simple while still supporting real release work.

## When Release Checks Fail

Start with these rules:

- if `doctor` fails, fix your local tool or environment first
- if `verify` fails, fix project generation or local Xcode setup first
- if `release-check` fails, fix release account, signing, or release files first
- if `release-run` fails, look at the logs in `.bos/artifacts/release-run/`

One important rule:

- if `release-check` says the discovered signing team does not match `profile.identity.appleTeamId`, fix the team ID before trying another signed build

## What Success Looks Like

After a normal successful setup flow, you should have:

- a generated iOS project
- a build/test verification result
- release scaffolding when needed
- logs and state summaries under `.bos/`

After a successful signed build, you should also have:

- a signed IPA file under `.bos/artifacts/release-run/`

## More Docs

- [Product Guide](./docs/PRODUCT_GUIDE.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Testing Guide](./docs/TESTING_GUIDE.md)
- [Tests Overview](./Tests/README.md)

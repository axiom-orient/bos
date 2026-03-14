# Metadata Contract

## Purpose

`metadata/` is the BOS-owned working tree for App Store text metadata. It exists so `bos metadata pull|diff|push|validate` can round-trip localized content without forcing operators to work directly in raw ASC payloads.

## Directory Layout

```text
metadata/
  README.md
  <locale>/
    name.txt
    subtitle.txt
    description.txt
    keywords.txt
    release_notes.txt
    promotional_text.txt
    marketing_url.txt
    support_url.txt
    privacy_url.txt
```

Rules:

- Locale folder names must be BCP-47 style values such as `en-US` or `ko-KR`.
- The default locale is `profile.release.primaryLanguage` when present, otherwise `blueprint.release.fastlane.primaryLanguage`.
- The default locale directory must exist before `push` or `validate` can pass.
- Required files for every locale:
  - `name.txt`
  - `subtitle.txt`
  - `description.txt`
  - `keywords.txt`
  - `release_notes.txt`
- Optional files:
  - `promotional_text.txt`
  - `marketing_url.txt`
  - `support_url.txt`
  - `privacy_url.txt`
- Unknown files are preserved by `pull`, reported by `diff`, and ignored by `push` unless a later contract explicitly owns them.

## Command Shape

All `bos metadata` commands must support `--format human|json` and return stable top-level keys.

### `bos metadata pull`

Purpose:

- fetch ASC metadata into `metadata/`
- materialize locale directories and tracked text files

JSON payload fields:

- `command`
- `status`
- `summary`
- `directory`
- `defaultLocale`
- `locales`
- `artifacts`

### `bos metadata diff`

Purpose:

- compare local `metadata/` against current ASC state

JSON payload fields:

- `command`
- `status`
- `summary`
- `directory`
- `defaultLocale`
- `hasChanges`
- `changedFiles`
- `missingLocales`
- `extraFiles`
- `artifacts`

### `bos metadata push`

Purpose:

- push local metadata to ASC using the BOS directory contract

JSON payload fields:

- `command`
- `status`
- `summary`
- `directory`
- `pushedLocales`
- `skippedLocales`
- `artifacts`

### `bos metadata validate`

Purpose:

- enforce locale completeness and file presence before push

JSON payload fields:

- `command`
- `status`
- `summary`
- `directory`
- `valid`
- `missingLocales`
- `missingRequiredFiles`
- `emptyRequiredFiles`
- `artifacts`

## Non-goals For This Contract Step

- binary screenshot or media upload
- raw ASC command parity
- introducing a separate metadata manifest file
- mutating profile or blueprint state during metadata sync

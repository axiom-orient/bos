# Metadata

This directory is the BOS working tree for localized App Store text metadata.

Expected locale layout:

```text
metadata/
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

Required files per locale:

- `name.txt`
- `subtitle.txt`
- `description.txt`
- `keywords.txt`
- `release_notes.txt`

Optional files per locale:

- `promotional_text.txt`
- `marketing_url.txt`
- `support_url.txt`
- `privacy_url.txt`

Canonical contract:

- see [docs/METADATA_CONTRACT.md](../docs/METADATA_CONTRACT.md)

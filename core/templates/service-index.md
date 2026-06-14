---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Service Index

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

> Auto-generated. Do not edit directly.
> Re-run `/draft:init` to update.

---

## Overview

| Metric | Count |
|--------|-------|
| Total Services Detected | [X] |
| Initialized | [Y] |
| Uninitialized | [Z] |

## Service Registry

| Service | Status | Tech Stack | Dependencies | Team | Details |
|---------|--------|------------|--------------|------|---------|
| [service-name] | ✓ | [lang, db] | [deps] | [@team] | [→ architecture](../services/[name]/draft/.ai-context.md) |
| [service-name] | ○ | - | - | - | Not initialized |

> **Status Legend:** ✓ = initialized, ○ = not initialized

## Uninitialized Services

The following services have not been initialized with `/draft:init`:

- `[path/to/service]/`

Initialize each one by running `/draft:init` inside its directory — it links the module's graph up to the root spine:
```bash
cd [path/to/service] && /draft:init
```

<!-- MANUAL START -->
## Notes

[Add any manual notes about services here - this section is preserved on re-index]

<!-- MANUAL END -->

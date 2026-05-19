# Guardrails — Baseline Ruleset

> **See also:** [`core/guardrails/README.md`](guardrails/README.md) for the full rule reference (SEC/CQ/DN/RC IDs) and precedence. This file contains the generalized systems programming guardrails and is loaded for C/C++ projects when language signals indicate. For other languages, see `core/guardrails/language-standards.md`. Generalized for public Draft (language-agnostic where possible) per manifest §2.1.

Mandatory baseline guardrails for quality commands. All quality commands (`/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:implement`, `/draft:debug`, `/draft:assist-review`) **must** enforce these rules where applicable. Violations are always flagged — no exceptions.

These guardrails are pre-seeded into every project's `draft/guardrails.md` by `/draft:init` and loaded at runtime via `core/shared/draft-context-loading.md` Layer 0.5.

**Source:** Generalized from proven internal systems guidelines.

---

## G1 — Object Lifecycle & Memory Safety (C++ example; opt-in for other stacks via language-standards)

### G1.1: No temporary strings in Printf-style trace APIs

Passing `.c_str()` of a temporary to `Printf`-style APIs that store format arguments by reference creates a dangling pointer. The temporary is destroyed at the end of the statement; the stored pointer becomes invalid.

- **Wrong:** `mem_tracer_->Printf("Bug: %s", my_proto->ShortDebugString().c_str());`
- **Fix:** Use `Print(StringPrintf(...))` when arguments include short-lived `.c_str()` pointers.

(Additional G rules generalized/conditioned; full list in language-standards.md for non-C++ and the plugin guardrails sub-system.)

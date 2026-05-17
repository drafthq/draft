# core/guardrails — Rules Reference

This directory contains the authoritative ruleset that Draft skills cite. Skills reference rules by ID (e.g. `[SEC-03]`, `[CQ-007]`, `[RC-012]`, `[DN-004]`); reviewers and auditors trace those IDs back here.

## Vocabulary

We use one word — **rule** — throughout the system. Avoid the synonyms below in skill prose:

| Use | Avoid |
|---|---|
| **rule** (with an ID) | guideline, principle, standard, check, norm, guardrail-item |
| **guardrail file** (this directory) | rulebook, policy file, standards doc |
| **guardrail breadcrumb** (`// guardrail: SEC-03 — reason`) | rule tag, policy comment, audit hint |

"Guardrail" by itself refers to a *file* in this directory (e.g. `core/guardrails/security.md`); individual items inside are always **rules** with IDs.

## Files & ID Prefixes

| File | Prefix | Scope |
|---|---|---|
| `security.md` | `SEC-01..SEC-10` | Hard security red lines (never cross these) |
| `code-quality.md` | `CQ-001..CQ-012` | Error handling, naming, error context, cleanup |
| `design-norms.md` | `DN-001..DN-010` | Module boundaries, coupling, API shape |
| `review-checks.md` | `RC-001..RC-015` | What reviewers verify per PR/track |
| `secure-patterns.md` | (cross-cites SEC) | Language-specific implementations of SEC rules |
| `dependency-triage.md` | `RC-014` (cross-cite) | Third-party dependency risk handling |
| `language-standards.md` | (no IDs) | Per-language style and idioms |

## Precedence (when rules conflict)

Apply in this order, highest first:

1. **Project-local guardrails** — `draft/guardrails.md` in the consuming repo. Project overrides ship-level defaults.
2. **`SEC-*`** — security red lines. These trump everything else; safety beats convenience and even correctness style.
3. **`RC-*`** — review checks. Anything a reviewer must verify before a PR merges.
4. **`CQ-*`** — code quality. Applied during implementation; reviewers re-verify under `RC-*`.
5. **`DN-*`** — design norms. Architectural guidance; only block a change if a clear `DN-*` rule is violated, not on stylistic preference.

If a `SEC-*` rule conflicts with a `DN-*` or `CQ-*` rule, `SEC-*` wins. If two `SEC-*` rules conflict (rare), prefer the one that's more restrictive (deny vs allow).

## How to cite a rule

In skill prose: `[SEC-03]`, `[CQ-006, CQ-007]`, `[RC-012]`.

In generated code (left by `implement` skill): `// guardrail: SEC-03 — parameterized query, no string interp`.

In reports (left by `review`/`bughunt`/`deep-review`): include the rule ID in the finding header, e.g. `**Critical [SEC-04]:** Plaintext credentials in process env`.

## Adding a new rule

1. Choose the right file (security → `security.md`, etc.).
2. Allocate the next ID in sequence — do not reuse retired IDs.
3. Add a one-line statement of the rule, then a short rationale and a fix example.
4. Update any skill that should reference it (`grep -rn "RC-014" skills/` for examples).
5. Run `make test` — `test-cross-references.sh` and frontmatter checks must still pass.

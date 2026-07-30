# Zero-Setup Review Mode

Full contract for running `/draft:review` on a repo that has never been indexed. Loaded when Step 0 detects no `draft/` directory.

## Why this mode exists

`/draft:init` is a multi-phase, token-heavy analysis. Requiring it before the first review puts the expensive step in front of the cheap one, so a new user pays before seeing anything. Zero-setup mode inverts that: review the diff now with whatever can be established from the code itself, then name precisely what indexing would have added.

The mode is a **reduction in evidence, never a reduction in rigor**. Every finding still requires a file, a line, and a reason. A finding you cannot ground in the diff is not reported — degraded mode is not license to guess at structure the graph would have told you.

## Detection

```bash
ls draft/ 2>/dev/null            # absent  -> zero-setup mode
ls draft/graph/schema.yaml       # absent  -> graph-less (may still have prose context)
```

Three states, and they are independent:

| `draft/` | `draft/graph/schema.yaml` | Mode |
|---|---|---|
| absent | absent | **zero-setup** — this document |
| present | absent | **graph-less** — prose context, no structural queries |
| present | present | full three-stage review |

Never print "Draft not initialized" and stop. That error is reserved for skills that genuinely cannot function without context (`/draft:learn`, `/draft:deep-review`, `/draft:tech-debt`, `/draft:implement`).

## Scope resolution without tracks

Track auto-detection needs `draft/tracks.md`, which does not exist. Resolve scope from git alone, first match wins:

1. Explicit `files <pattern>` or `commits <range>` argument → use it.
2. Uncommitted changes present (`git diff HEAD --shortstat` non-empty) → review those.
3. Current branch diverges from the default branch → review `<default>...HEAD`.

   ```bash
   default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
   default="${default:-$(git config --get init.defaultBranch || echo main)}"
   git diff --shortstat "$default...HEAD"
   ```

4. Neither → review the last commit (`git show --stat HEAD`), and say that is what you did.
5. Empty repository → the one legitimate stop. Print: `No changes to review. Make a change, or run /draft:review commits <range>.`

## Stage behavior

| Stage | Zero-setup behavior |
|---|---|
| **1. Automated Validation** | Runs. Detect the test/lint/type-check commands from the manifest present in the repo (`package.json` scripts, `Makefile` targets, `pyproject.toml`, `Cargo.toml`, `go.mod`). Run what is discoverable; report each as run/failed/not-found. Never invent a command. |
| **1.5. HLD/LLD conformance** | Skipped — no design docs exist. |
| **2. Spec Compliance** | Skipped — no spec exists. Do not substitute the commit message for a spec; say the stage was skipped and why. |
| **3. Code Quality** | Runs, all four dimensions (security, correctness, performance, maintainability), against plugin guardrails only (`core/guardrails/review-checks.md`, `security.md`, `language-standards.md` for the detected stack). |
| **Adversarial pass** | Runs, and is still mandatory on zero findings. Fewer inputs make a false "clean" more likely, not less. |

Guardrail citations still apply — `[SEC-03]`, `[RC-012]`. They come from the plugin, not the project, so they are available with no setup.

## What degrades, precisely

State these as limitations in the report rather than silently omitting them:

| Unavailable | Consequence for this review |
|---|---|
| Blast radius (`graph-impact.sh`) | Cannot say what else breaks. Severity of a signature change is judged from the diff only, so a breaking change with distant callers may read as Minor. |
| Caller enumeration (`graph-callers.sh`) | Cannot enumerate downstream callers of a modified public symbol. |
| Fan-in hotspot ranking (`hotspot-rank.sh`) | Cannot flag "you just edited the most-depended-on file in the repo." |
| Cycle detection | Cannot detect a newly introduced dependency cycle. |
| Module boundary check `[RC-013]` | Cannot verify the change respects intended module boundaries. |
| `draft/guardrails.md` | Project-specific learned conventions and anti-patterns are unknown, so findings that a team has already accepted as intentional may appear as issues. |
| `tech-stack.md` Accepted Patterns | Deliberate trade-offs are not suppressed — expect a higher false-positive rate. |
| Spec / acceptance criteria | No verdict on whether the change does what was asked. |

The false-positive caveat is the honest one to surface: without Accepted Patterns and learned conventions, some findings will be things the team decided on purpose.

## Output

**Render the report in the conversation. Write no files.** A user evaluating the tool has not asked for artifacts in their repo, and an unrequested `draft/` write is exactly the friction this mode removes.

Header (replaces the standard git-metadata frontmatter, which assumes a report file):

```text
Review — zero-setup mode
Scope:   <what was reviewed, and how it was chosen>
Context: none (draft/ not present)
Graph:   unavailable
Checks:  <test/lint commands run, or "none discoverable">
```

Then Stage 1 results, Stage 3 findings grouped by severity, and the limitations table above trimmed to what actually mattered for this diff.

If the user asks to save it, write `.draft-review/review-report-<timestamp>.md` (`date +%Y-%m-%dT%H%M`) and tell them the path. Do not create `draft/` — that directory is `/draft:init`'s to own.

## Closing call to action

End every zero-setup review with a concrete, quantified upgrade line. Name real numbers from this run, not a generic pitch:

```text
Found <N> issues in <M> files (<C> Critical, <I> Important, <m> Minor).

Not checked: blast radius, downstream callers, dependency cycles, module
boundaries, and your project's own accepted patterns.

  /draft:init      index this repo (one time) — adds the structural checks above
  /draft:review    re-run with them enabled
```

If the review found nothing, the CTA is the same but framed on coverage rather than count: say which structural checks never ran, so "clean" is not overclaimed.

## Anti-patterns specific to this mode

| Don't | Instead |
|---|---|
| Stop with "Draft not initialized" | Review the diff, then invite indexing |
| Claim blast radius or hotspot findings without the graph | Say the check did not run |
| Report "no issues found" without the adversarial pass | Run it — thin input raises the bar, not lowers it |
| Write into `draft/` to store the report | Render inline; `.draft-review/` only on request |
| Pitch `/draft:init` generically | Name the specific checks this diff missed |
| Treat the commit message as a spec | Mark Stage 2 skipped |

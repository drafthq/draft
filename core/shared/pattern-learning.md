# Pattern Learning — Post-Analysis Phase

Shared procedure for auto-discovering coding patterns after quality analysis. Run as the final phase of `/draft:bughunt`, `/draft:deep-review`, and `/draft:review`.

Referenced by: `/draft:bughunt`, `/draft:deep-review`, `/draft:review`, `/draft:learn`

---

## When to Run

Execute this phase **after** the main analysis and report generation are complete. This phase updates `draft/guardrails.md` with newly discovered patterns.

**Skip this phase if:**
- `draft/` directory does not exist (no Draft context)
- Analysis found zero findings to learn from
- Running in a read-only or preview mode

---

## Step 1: Identify Pattern Candidates

Review the findings from the just-completed analysis and identify:

### Convention Candidates (patterns to NOT flag in future)

Look for patterns that were **considered during analysis but determined to be intentional**:

- Patterns checked during the Pattern Prevalence Check that were found >3x and all instances were correct
- Patterns that matched a framework idiom confirmed by documentation
- Patterns flagged as MEDIUM confidence but verified as intentional after investigation
- Recurring code structures that follow a consistent project convention

### Anti-Pattern Candidates (patterns to ALWAYS flag in future)

Look for patterns that were **confirmed as bugs across multiple locations**:

- Bug patterns found in 3+ locations with the same root cause
- Patterns that violate documented invariants consistently
- Security or reliability patterns that appeared as confirmed bugs

---

## Step 2: Apply Confidence Threshold

| Evidence | Confidence | Action |
|----------|------------|--------|
| Pattern found 1-2x | — | Do not learn (insufficient data) |
| Pattern found 3-5x, all consistent | `medium` | Add to guardrails.md |
| Pattern found >5x, all consistent, verified across multiple files | `high` | Add to guardrails.md, suggest promotion |
| Pattern found >5x but some instances are buggy | — | Do NOT learn (inconsistent — real problem exists) |

---

## Step 3: Check for Duplicates

Before adding a new entry to `draft/guardrails.md`:

1. Read current `draft/guardrails.md`
2. Check if the pattern already exists under Learned Conventions or Learned Anti-Patterns
3. If it exists:
   - Update `last_verified` and `last_active` dates
   - Increase evidence count if new instances were found
   - Upgrade confidence from `medium` → `high` if threshold met
   - Preserve original `discovered_at` and `established_at` dates (never overwrite these)
4. If it does NOT exist: append as new entry with all four timestamps populated

---

## Step 4: Write to guardrails.md

### 4.0: Update Project Metadata

Before writing entries, update `draft/metadata.json` with the current git state — this is the single source of truth for `synced_to_commit` and all `git.*` fields for project-level artifacts including `guardrails.md`. Use `git-metadata.sh --project-metadata --generated-by "draft:learn"` or update `git.commit`, `git.commit_short`, `git.commit_date`, `git.commit_message`, and `synced_to_commit` manually. Do NOT write these fields to `guardrails.md` frontmatter (WS-8).

### Convention Entry Format

Append under `## Learned Conventions`:

```markdown
### [Pattern Name]
- **Category:** error-handling | naming | architecture | concurrency | state-management | data-flow | testing | configuration
- **Confidence:** high | medium
- **Evidence:** Found in N files — `path/file1.ext:line`, `path/file2.ext:line`, `path/file3.ext:line`
- **Discovered at:** YYYY-MM-DD (when Draft first observed this pattern)
- **Established at:** YYYY-MM-DD (when the pattern entered the codebase, via git blame)
- **Last verified:** YYYY-MM-DD
- **Last active:** YYYY-MM-DD (when source files containing this pattern were last modified)
- **Discovered by:** draft:[command] on YYYY-MM-DD
- **Description:** [What the pattern is and why it's intentional]
```

### Anti-Pattern Entry Format

Append under `## Learned Anti-Patterns`:

```markdown
### [Anti-Pattern Name]
- **Category:** security | reliability | performance | correctness | concurrency
- **Severity:** critical | high | medium
- **graph_severity:** critical | high | medium | low | unresolved (derived from fanIn of evidence files; "unresolved" if no graph data available)
- **high_fanin_files:** `path/file.go` (fanIn:12), `path/other.go` (fanIn:7) (omit line if none meet fanIn ≥ 5)
- **Evidence:** Found in N files — `path/file1.ext:line`, `path/file2.ext:line`
- **Discovered at:** YYYY-MM-DD (when Draft first observed this pattern)
- **Established at:** YYYY-MM-DD (when the pattern entered the codebase, via git blame)
- **Last verified:** YYYY-MM-DD
- **Last active:** YYYY-MM-DD (when source files containing this pattern were last modified)
- **Discovered by:** draft:[command] on YYYY-MM-DD
- **Description:** [What the pattern is and why it's problematic]
- **Suggested fix:** [Brief description of the correct approach]
```

`graph_severity` derivation rules (from live hotspot query `scripts/tools/hotspot-rank.sh --repo .` fanIn values):
- fanIn ≥ 10 in any evidence file → `critical`
- fanIn 5–9 → `high`
- fanIn 1–4 → `medium`
- fanIn 0 or file not returned by hotspot query → `low`
- Graph data absent → `unresolved`

When `graph_severity` differs from `severity`, use `graph_severity` as the enforcement priority — it is objective and graph-derived.

---

## Step 5: Report Learning Summary

After updating guardrails.md, append a brief learning summary to the end of the quality report:

```markdown
## Pattern Learning

| Action | Count | Details |
|--------|-------|---------|
| New conventions learned | N | [names] |
| New anti-patterns learned | N | [names] |
| Existing patterns re-verified | N | [names] |
| Promotion candidates (high confidence) | N | [names] |
```

---

## Constraints

- **Never auto-promote** learned patterns to Hard Guardrails — that requires human decision via `/draft:learn promote`
- **Never remove** existing entries — only update evidence/confidence/dates
- **Cap at 50 learned entries** per section — if at capacity, replace the oldest `medium` confidence entry that hasn't been re-verified in 90+ days
- **Human-curated always wins** — Hard Guardrails and `tech-stack.md ## Accepted Patterns` take precedence over learned patterns if there's a conflict
- **Preserve project metadata** — update `draft/metadata.json:synced_to_commit` when modifying `guardrails.md`; do NOT write `synced_to_commit` to `guardrails.md` frontmatter (WS-8)

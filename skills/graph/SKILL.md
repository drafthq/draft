---
name: graph
description: Initialize or refresh the knowledge-graph snapshot for a repository. Ensures the codebase-memory-mcp engine is present (fetching it if needed), then builds draft/graph/ and reports engine, counts, hotspots, and cycles. Accepts an optional repo path.
---

# Draft Graph

Initialize or refresh the `draft/graph/` knowledge-graph snapshot for a single repository. This is the narrow "give me a fresh structural graph" command — it does **not** generate `architecture.md`/`.ai-context.md` and does **not** re-inject doc diagram slots (both are `/draft:init`). For scope-aware, root-first graph memory across a monorepo (root spine + module→root links), use `/draft:init --graph-only`.

## Red Flags - STOP if you're:

- Reporting counts without actually running `graph-snapshot.sh`
- Claiming the graph is built when the engine was unavailable
- Treating an engine-unavailable result as a hard failure (it degrades gracefully)
- Running against a path that isn't a directory

**Build, then report what the tools actually returned.**

---

## Step 1: Resolve the target repo

The command takes an optional path argument: `/draft:graph [path]`.

- No argument → use the current directory (`.`).
- With a path → use it as the repo root.

```bash
REPO="${1:-.}"
if [ ! -d "$REPO" ]; then
  echo "ERROR: '$REPO' is not a directory."
  exit 1
fi
REPO_ABS="$(cd "$REPO" && pwd)"
echo "Target repo: $REPO_ABS"
```

## Step 2: Ensure the engine is present

Resolve the engine; if it is missing, fetch it once, then re-check. If it is still unavailable (e.g. offline, opted out via `DRAFT_MEMORY_DISABLE`), report and stop gracefully — graph features are optional everywhere in Draft.

```bash
if ! scripts/tools/verify-graph-binary.sh --repo "$REPO_ABS" --json 2>/dev/null | grep -q '"status":"ok"'; then
  echo "Graph engine not found — attempting to fetch it..."
  scripts/fetch-memory-engine.sh || true
fi

ENGINE="$(scripts/tools/verify-graph-binary.sh --repo "$REPO_ABS" --json 2>/dev/null || true)"
if ! echo "$ENGINE" | grep -q '"status":"ok"'; then
  echo "Graph engine unavailable — skipping. Install with scripts/fetch-memory-engine.sh, or unset DRAFT_MEMORY_DISABLE."
  exit 0
fi
echo "Engine: $ENGINE"
```

## Step 3: Build / refresh the snapshot

One call resolves the engine, indexes the repo (incrementally on refresh), and writes the committed snapshot under `<repo>/draft/graph/` — `schema.yaml`, `architecture.json`, `hotspots.jsonl`, `module-deps.mermaid`, `proto-map.mermaid`, and an Open Knowledge Format bundle under `okf/` (a portable, vendor-neutral markdown mirror of the graph — `index.md` + one cross-linked `modules/<name>.md` concept per module).

```bash
scripts/tools/graph-snapshot.sh --repo "$REPO_ABS"
```

If this exits non-zero, the engine became unavailable mid-run — report it and stop; do not fabricate results.

## Step 4: Report

Summarize what the snapshot contains. Read `draft/graph/schema.yaml` for engine/version/counts, and use the live tools for a quick health view:

```bash
echo "--- Snapshot ---"
cat "$REPO_ABS/draft/graph/schema.yaml"

echo "--- Top hotspots ---"
scripts/tools/hotspot-rank.sh --repo "$REPO_ABS" --top 5

echo "--- Cycles ---"
scripts/tools/cycle-detect.sh --repo "$REPO_ABS"

echo "--- Snapshot state ---"
git -C "$REPO_ABS" rev-parse --short HEAD 2>/dev/null \
  && { git -C "$REPO_ABS" diff --quiet 2>/dev/null || echo "(working tree dirty — snapshot reflects uncommitted changes)"; }
```

Present a concise summary:

- **Engine**: version + resolution source (path / managed / bundled / override)
- **Graph**: node and edge counts (from `schema.yaml`)
- **Top hotspots**: the highest fan-in symbols
- **Cycles**: count, or `None ✓`
- **Freshness**: the commit the snapshot reflects, and whether the tree was dirty

Then point the user at the natural next steps:

- To re-inject the refreshed diagrams/hotspot tables into `architecture.md` / `.ai-context.md`: run `/draft:init refresh` (or `/draft:init --graph-only` to rebuild just the graph memory).
- For a first-time full context bootstrap (architecture + profiles): run `/draft:init`.

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| Engine resolvable | Build snapshot, report counts/hotspots/cycles |
| Engine missing, fetch succeeds | Build proceeds after fetch |
| Engine missing, fetch fails / `DRAFT_MEMORY_DISABLE=1` | Report unavailable and exit 0 — no error, no partial snapshot |
| Path not a directory | Exit 1 with a clear message |

See `core/shared/graph-query.md` and `bin/README.md` for the query contract and engine resolution.

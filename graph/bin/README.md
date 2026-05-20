# Graph Binary Distribution (Draft)

The Draft knowledge graph engine is a **native binary** (Aether graph) with an optional `graph-clang` companion for high-fidelity C/C++ extraction.

No JavaScript/Node component remains. The legacy `graph/bin/graph` shim and `graph/src/` tree have been removed.

## Layout

```
graph/bin/
├── README.md
├── linux-amd64/
│   ├── graph          # Native graph binary (LFS-tracked when real)
│   └── graph-clang    # Optional C/C++ companion (LFS)
├── darwin-arm64/
│   ├── graph
│   └── graph-clang
└── (linux-arm64/, darwin-x86_64/, windows-amd64/ ... as released)
```

Placeholders under each arch directory are zero-byte files or small markers until real release artifacts are staged by `scripts/build-graph-binaries.sh` (or copied from the Aether build tree).

## Binary Preference Order

Detection (used by `skills/init/SKILL.md`, `scripts/tools/verify-graph-binary.sh`, and `scripts/tools/_lib.sh`):

1. **PATH first** — `command -v graph` (and `graph-clang`). Highest priority for developer installs and CI.
2. **Bundled arch-specific** — Relative to the Draft plugin or repo:
   - `graph/bin/<os>-<arch>/graph` (and sibling `graph-clang`)
   - Arch is normalized: `linux-amd64`, `darwin-arm64`, `linux-arm64`, etc.

`graph-clang` is always discovered as a sibling of the chosen `graph` binary.

If neither is present, graph features silently degrade (skills record `Graph files queried: NONE — graph data unavailable`).

## Git LFS

Large native binaries are stored via Git LFS:

```
graph/bin/*/graph filter=lfs diff=lfs merge=lfs -text
graph/bin/*/graph-clang filter=lfs diff=lfs merge=lfs -text
```

`scripts/install.sh` and `scripts/package.sh` perform `git lfs pull` (or materialize from tarball) during install.

## Building / Staging Binaries

Use `scripts/build-graph-binaries.sh` (from the Aether build outputs) to populate `graph/bin/<arch>/` for a release.

See also:
- `scripts/tools/verify-graph-binary.sh` — runtime resolver + arch selection
- `skills/init/SKILL.md` (Step 1.4) — the actual invocation during project initialization

## Query / Output Contract

The CLI surface (`graph --repo`, `graph --query --mode ...`) and the `draft/graph/*.jsonl` schema are stable and documented in:

- `graph/README.md`
- `core/shared/graph-query.md` (mandatory lookup contract for all skills)

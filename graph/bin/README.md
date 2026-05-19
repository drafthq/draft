# Graph Binary Distribution (Draft)

Draft supports a **dual-mode graph engine** during the binary adoption transition (Phase 3 skeleton).

- Legacy: `graph` (this directory) — Node.js wrapper around `../dist/bundle.cjs` (tree-sitter WASM). Preserved; not deleted.
- Native (new): High-performance Rust `graph` binary with optional `graph-clang` companion for superior C/C++ extraction fidelity.

## Layout

```
graph/bin/
├── graph                 # Legacy Node wrapper (#!/usr/bin/env node; always kept for fallback)
├── README.md             # This file
├── linux-amd64/
│   ├── graph             # Placeholder for native `graph` (real binary tracked via Git LFS)
│   └── graph-clang       # Optional high-fidelity C/C++ companion (LFS)
├── linux-arm64/
│   ├── graph
│   └── graph-clang
├── darwin-arm64/
│   ├── graph
│   └── graph-clang
├── darwin-x86_64/
│   └── ...
└── (windows-amd64/ etc. as needed)
```

Placeholders in arch dirs are small text files or symlinks until replaced by release artifacts. Real prebuilts are produced by `scripts/build-graph-binaries.sh` and vendored here for plugin distribution.

## Binary Preference Order (Detection Logic)

All consumers (skills/init graph section, core/shared/graph-query.md, tools) use this order:

1. **PATH first** — `command -v graph` (and `graph-clang`). Preferred for native installs or user-provided binaries. Verified executable and responsive to `--help`.
2. **Bundled arch-specific** — Relative to plugin root (via .draft-install-path breadcrumb or known paths):
   `graph/bin/<os>-<arch>/graph` and sibling `graph-clang` (os/arch normalized from uname: linux-amd64, darwin-arm64, etc.).
3. **Legacy Node** — `graph/bin/graph` (the wrapper present today).

If a preferred candidate is missing or fails basic exec check, fall through with clear log messages (e.g., "Preferring PATH graph: /usr/local/bin/graph", "No native graph-clang found; using ctags fallback if needed", "Falling back to legacy Node graph").

`graph-clang` is discovered relative to chosen `graph` (same dir or PATH sibling or `graph/bin/<arch>/graph-clang`).

## Git LFS for Binaries

Native binaries (>10MB) must be stored via Git LFS to keep the repo clone light.

Add to repository root `.gitattributes`:

```
graph/bin/*/graph filter=lfs diff=lfs merge=lfs -text
graph/bin/*/graph-clang filter=lfs diff=lfs merge=lfs -text
graph/bin/linux-amd64/graph filter=lfs diff=lfs merge=lfs -text
# ... repeat for each arch as populated
```

**Install-time requirements** (handled or documented by `scripts/install.sh` and `scripts/package.sh`):

- `git lfs install`
- After clone or extract: `git lfs pull` (or the package tarball includes the resolved LFS objects)
- The `package.sh` produces a self-contained `draft/` tree or tarball with LFS objects materialized.

See:
- `scripts/build-graph-binaries.sh` — generalized builder/stager (no internal paths; emits to graph/bin/<arch>/)
- `scripts/tools/verify-graph-binary.sh` — runtime check + arch selection helper
- `Makefile` targets: `graph-binaries`, `verify-graph`
- `scripts/install.sh`, `scripts/package.sh` — packaging entrypoints that respect LFS and produce Draft artifacts only

## Transition Notes

- Existing Node `src/`, `dist/`, `build.js`, `analyze-repo.sh` remain untouched.
- Detection and wrappers keep full backward compat: if no native present, legacy path is used exactly as before.
- Later phases may promote native to default or remove Node after validation.
- All messages and paths use "Draft" terminology and `/draft:` commands.

This skeleton enables future prebuilt shipping while preserving the working graph today.

# graph Binary (Architecture-Specific)

This directory contains architecture-specific `graph` binaries (and optional `graph-clang` companions).

## Canonical Layout (arch-specific only)

```
codev/bin/
├── linux-amd64/
│   ├── graph
│   └── graph-clang   (optional)
├── linux-arm64/
│   ├── graph
│   └── graph-clang   (optional)
├── darwin-amd64/
│   └── ...
└── darwin-arm64/
    └── ...
```

**Only** architecture-specific subdirectories are kept. There is no top-level `bin/graph` shim.

## How Codev Selects the Binary

Codev computes the current host triple (`uname -s`-`uname -m`, normalized: linux-amd64, linux-arm64, darwin-arm64, etc.) and looks for:

1. `graph` in `$PATH` (strongly preferred for dev and global installs)
2. `bin/<os>-<arch>/graph` relative to the Codev plugin root (canonical)
3. Legacy flat `bin/graph` (transitional only; will be removed)

When running `/codev:init`, the embedded detector (Step 1.4) and `scripts/tools/_lib.sh:find_graph_bin()` both implement this selection.

## Ensuring the Correct Binary for the Invocation Host

**Critical**: The binary placed under `bin/<os>-<arch>/` must match the architecture of the machine where `/codev:init` (or any graph-using command) executes.

- On an x86_64 Linux machine: provide `bin/linux-amd64/graph`
- On an aarch64 Linux machine: provide `bin/linux-arm64/graph`
- On Apple Silicon (arm64 macOS): provide `bin/darwin-arm64/graph`

Cross-arch binaries will fail to execute. If the required arch directory is empty or the binary is missing for the current host, the command falls back to `$PATH` or errors with a clear message.

## Development

Build the Rust `graph` crate for the desired target triple and stage the resulting executable into the matching `bin/<triple>/` directory.

Example (from aether/ checkout):
```bash
cargo build --release -p graph --bin graph
mkdir -p ../codev/bin/linux-amd64
cp target/release/graph ../codev/bin/linux-amd64/graph
```

## Distribution

When packaging Codev, populate each `bin/<os>-<arch>/` directory with the matching pre-built binary for that platform. The install process (or manual placement) must ensure the host where the plugin runs has the corresponding arch binary present.

## Storage (Git LFS)

Architecture-specific binaries are tracked with **Git LFS**:

```bash
git lfs install
git lfs pull
git lfs track "bin/*/*/graph*" "bin/*/*/graph-clang*"
git add bin/ .gitattributes
```

## Backward Compatibility Note

Older installs that still rely on a flat `bin/graph` will continue to work via the legacy fallback in the resolver until that path is fully retired. New distributions should only ship the arch-specific layout.

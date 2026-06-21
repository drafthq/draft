---
type: Subsystem                    # required (OKF) — one of the frozen vocab below
title: "{CONCEPT_TITLE}"           # OKF
description: >                     # OKF — LOAD-BEARING: the agent's routing key.
  Write this as a ROUTING DECISION, not a summary. It must answer
  "should the agent open this file for the task at hand?" from the index
  alone. Name the responsibilities and the words a task would use.
resource: "{CANONICAL_SOURCE_PATH}"   # OKF — canonical source path(s)
tags: [tag1, tag2]                 # OKF
timestamp: "{ISO_TIMESTAMP}"       # OKF — last regeneration
# Draft extensions (ignored by generic OKF consumers; namespaced x-):
x-grounded-paths: ["{path/a}", "{path/b}"]   # exact source files this page grounds
x-hotspot-score: 0.0                          # from hotspot-rank.sh (0..1)
x-callers: ["{module/a}", "{module/b}"]       # from graph-callers.sh
---

# {CONCEPT_TITLE}

<!--
Frozen `type` vocabulary (changing it churns every file — versioned via
index.md: okf_types_version):
  Subsystem  — major graph cluster / package boundary        → systems/
  Module     — single package/dir with cohesive responsibility → systems/
  Feature    — user-facing capability spanning modules         → features/
  Entrypoint — binary / main / CLI / handler root              → entrypoints/
  API        — public interface, route group, RPC surface      → reference/
  DataModel  — schema, table, core struct/type                 → reference/
  Dependency — notable external dep + how it's used            → reference/
  ADR        — architecture decision record                    → reference/
  Runbook    — operational procedure                           → reference/
-->

## What it is

One paragraph: the concept's responsibility and boundary. Graph-grounded.

## How it works

Primary control/data flow. At least one Mermaid diagram for a significant
concept (workflow, state, or sequence). Grounded in the call graph.

## Used by

Cross-links to callers (from `x-callers`). Each link is a relative path to
another concept page so `okf-validate.sh` can resolve it.

## Blast radius

What breaks if this changes (from `graph-impact.sh`). Lists `x-grounded-paths`
so a focused task knows exactly which source files to open.

## See also

- [Related concept](../systems/other.md)

<!-- okf:concept-template v1
A stub or redirect-only page (e.g. "see architecture.md", an unreplaced
{PLACEHOLDER} token, or a body below the per-type minimum) FAILS
okf-validate-quality.sh and therefore does NOT satisfy okf-coverage-check.sh —
the bundle will not be promoted. Diagram types (Subsystem/Module/Feature/
Entrypoint) require ≥1 valid Mermaid block and ≥2 x-grounded-paths.
-->


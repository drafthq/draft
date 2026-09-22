# codebase-memory-mcp usage remediation

> Verify-first: 1) re-read row + source doc · 2) `git log` + grep the symbol on main ·
> 3) confirm still required · 4) flip shipped/obsolete rows with evidence. Then code.

Source: [docs/audit/codebase-memory-mcp-usage-2026-09-21.md](../../audit/codebase-memory-mcp-usage-2026-09-21.md)

- [x] CMM-1 · H3 pass engine args on stdin, not deprecated raw-JSON argv · ef9b894
- [x] CMM-2 · H4 isolate tests from the real engine and its cache · f02cd40
- [x] CMM-3 · H4 real-engine smoke test + CI job that fetches the pinned engine · 878b05e
- [x] CMM-4 · H1 refresh a stale index before live queries · 3901b15
- [x] CMM-5 · H2 `graph-impact --file` returns cross-file dependents, fails loud on no-change · 8119699, 753da6b
- [x] CMM-6 · L1 `graph-impact --symbol` carries caller file paths · 8119699
- [x] CMM-7 · M1 pin per-platform SHA-256 in the fetch script · f7ee5f7
- [x] CMM-8 · M2 enforce the pinned engine version (fetch upgrade + verify warning) · f7ee5f7
- [x] CMM-9 · M3 resolve repo paths physically (`pwd -P`) · e5e1058
- [x] CMM-10 · M4 fail loud on engine project-name collision · 273072b
- [x] CMM-11 · M5 cycle-detect: drop degenerate rows, dedupe rotations · 2ecf1f9
- [x] CMM-12 · M6 docs: route raw engine calls through graph-query.sh; drop "self-freshens" · f858c86
- [x] CMM-13 · M7 re-verify and update the Cypher dialect list for 0.9.0 · 981fa02
- [x] CMM-14 · L2 hotspot enrichment scoped to hotspot symbols · ae42780
- [x] CMM-15 · L3 graph-snapshot indexes once on a fresh repo · 1161d96
- [x] CMM-16 · L4 portable memory bound via CBM_MEM_BUDGET_MB · f10c60f
- [x] CMM-17 · L5 keep machine-specific fields out of committed schema.yaml · c051ec0, 7a0e4d9
- [x] CMM-18 · L6 scope the "no outbound calls" claim to CLI mode · 883e2d2
- [x] CMM-19 · condensation tier reads `stats.*` fields schema.yaml never had (found during CMM-17) · 2ea6e10, bd43842

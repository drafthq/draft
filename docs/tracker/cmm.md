# codebase-memory-mcp usage remediation

> Verify-first: 1) re-read row + source doc · 2) `git log` + grep the symbol on main ·
> 3) confirm still required · 4) flip shipped/obsolete rows with evidence. Then code.

Source: [docs/audit/codebase-memory-mcp-usage-2026-09-21.md](../audit/codebase-memory-mcp-usage-2026-09-21.md)

- [ ] CMM-1 · H3 pass engine args on stdin, not deprecated raw-JSON argv · P0
- [ ] CMM-2 · H4 isolate tests from the real engine and its cache · P0
- [ ] CMM-3 · H4 real-engine smoke test + CI job that fetches the pinned engine · P0
- [ ] CMM-4 · H1 refresh a stale index before live queries · P0
- [ ] CMM-5 · H2 `graph-impact --file` returns cross-file dependents, fails loud on no-change · P0
- [ ] CMM-6 · L1 `graph-impact --symbol` carries caller file paths · P2
- [ ] CMM-7 · M1 pin per-platform SHA-256 in the fetch script · P1
- [ ] CMM-8 · M2 enforce the pinned engine version (fetch upgrade + verify warning) · P1
- [ ] CMM-9 · M3 resolve repo paths physically (`pwd -P`) · P1
- [ ] CMM-10 · M4 fail loud on engine project-name collision · P1
- [ ] CMM-11 · M5 cycle-detect: drop degenerate rows, dedupe rotations · P1
- [ ] CMM-12 · M6 docs: route raw engine calls through graph-query.sh; drop "self-freshens" · P1
- [ ] CMM-13 · M7 re-verify and update the Cypher dialect list for 0.9.0 · P2
- [ ] CMM-14 · L2 hotspot enrichment scoped to hotspot symbols · P2
- [ ] CMM-15 · L3 graph-snapshot indexes once on a fresh repo · P2
- [ ] CMM-16 · L4 portable memory bound via CBM_MEM_BUDGET_MB · P2
- [ ] CMM-17 · L5 keep machine-specific fields out of committed schema.yaml · P2
- [ ] CMM-18 · L6 scope the "no outbound calls" claim to CLI mode · P2

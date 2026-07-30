## What this changes

<!-- One or two sentences. What behavior is different after this merges? -->

## Why

<!-- The problem it solves. Link the issue if there is one. -->

## Checklist

- [ ] `make test` passes
- [ ] `make lint` passes (shellcheck is blocking; markdownlint is advisory)
- [ ] `make build` run and `integrations/` committed, if any skill or core file changed
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` — Release notes are generated from it
- [ ] New skill? Registered in `SKILL_ORDER` **and** `SKILL_META` (`scripts/lib.sh`), documented in `docs/COMMANDS.md`
- [ ] New tool? Registered in `TOOLS` (`scripts/lib.sh`) with a `tests/test-tools-<name>.sh` wired into the `Makefile`

## Source of truth

<!-- Delete what does not apply. -->

Changes follow the hierarchy: `core/methodology.md` → `skills/<name>/SKILL.md` → `integrations/` (generated, never hand-edited).

## Verification

<!-- Paste the evidence, not the assertion. Test output, command output, a
     before/after. "Tests pass" without output is not verification. -->

```

```

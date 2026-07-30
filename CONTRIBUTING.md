# Contributing to Draft

## Development Setup

```bash
git clone https://github.com/drafthq/draft.git
cd draft
make build    # Generate integration files
make test     # Run tests
make lint     # Run linters (requires shellcheck, markdownlint-cli)
```

### Prerequisites

- Bash 4.0+
- Node 18+ — the `draft` CLI and several test suites
- `jq` — the graph tooling and its tests
- [shellcheck](https://github.com/koalaman/shellcheck) — shell script linting
- [markdownlint-cli](https://github.com/igorshubovych/markdownlint-cli) — markdown linting
- (Optional) [pre-commit](https://pre-commit.com/) — git hook management

Install pre-commit hooks:
```bash
pre-commit install
```

## Branch Strategy

- `main` — stable release branch
- Feature branches: `feat/<description>`
- Bug fixes: `fix/<description>`
- Docs: `docs/<description>`

Always branch from `main`. Keep branches short-lived.

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

Types: feat, fix, docs, chore, refactor, test, ci
Scopes: skills, core, integrations, scripts, tests
```

Examples:
```
feat(skills): add /draft:migrate command
fix(new-track): handle empty track names
docs(readme): update installation instructions
ci(workflows): add shellcheck to CI pipeline
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make changes following the source of truth hierarchy:
   - `core/methodology.md` first (if methodology changes)
   - `skills/<name>/SKILL.md` (command implementations)
   - Run `./scripts/build-integrations.sh` to regenerate integrations
3. Run `make test` and `make lint`
4. Open a PR against `main`
5. Fill out the PR template checklist

### PR Review Criteria

- Tests pass
- Lint checks pass
- Integration files regenerated (if skills changed)
- No breaking changes without discussion
- Follows existing code patterns

### What CI Runs

`.github/workflows/ci.yml` runs on every push to `main` and every pull request:

| Job | Checks | Blocking |
|---|---|---|
| **Install path** | `check-repo-size.sh` (tree at HEAD under the size cap) and `install-smoke-test.sh` (shallow clone → manifest discovery → per-host `--dry-run` install) | Yes |
| **Test suites** | `make test`, plus a check that `integrations/` matches a fresh `make build` | Yes |
| **Lint** | shellcheck over `scripts/` and `tests/` | Yes |
| **Lint** | markdownlint over `**/*.md` | No — advisory against a large pre-existing backlog |

Reproduce the install-path jobs locally before pushing:

```bash
bash scripts/tools/check-repo-size.sh
bash scripts/tools/install-smoke-test.sh
```

The size cap exists because `plugin marketplace add` git-clones this repository: anything committed to HEAD is downloaded before the plugin can install. Ship large assets as GitHub Release attachments, never as commits.

## Releasing

`package.json` is the single source of truth for the version. Never hand-edit it anywhere else.

```bash
npm version <patch|minor|major>     # syncs the plugin manifests via the version hook
git push --follow-tags origin main  # the tag push publishes a GitHub Release
npm publish
```

Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which verifies the tag matches `package.json`, extracts that version's section from `CHANGELOG.md` via `scripts/release-notes.sh`, and publishes the Release. Write the changelog entry *before* tagging — the Release notes come from it.

Preview what a Release will say:

```bash
bash scripts/release-notes.sh --latest
bash scripts/release-notes.sh 3.6.0 --title
```

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: Brief description of the command
---
# Skill Title

Execution instructions...
```

2. The body **must** start with `# Title` followed by a blank line (build script skips first 3 body lines via `tail -n +4`)
3. Add the skill name to the `SKILL_ORDER` array in `scripts/lib.sh`, then add a `<name>|<header>|<trigger>` row to `SKILL_META` in the same file (`tests/test-trigger-functions.sh` checks the coverage)
4. Run `make build && make test`
5. Add the command to `docs/COMMANDS.md` — the README deliberately lists only the five primary commands
6. Add a test if the skill has validatable behavior

### Adding a New Tool

1. Create `scripts/tools/<tool-name>.sh` (kebab-case). It must use `#!/usr/bin/env bash`, `set -euo pipefail`, and support `--help`
2. Add it to the `TOOLS` array in `scripts/lib.sh`
3. Create `tests/test-tools-<tool-name>.sh` and add it to `TEST_SCRIPTS` in the `Makefile`
4. Run `make test`

## Source of Truth Hierarchy

1. `core/methodology.md` — Master methodology documentation
2. `skills/<name>/SKILL.md` — Skill implementations (derive from methodology)
3. `integrations/` — Auto-generated from skills (never edit directly)

## Reporting Issues

- **Bugs:** Use the [bug report template](https://github.com/drafthq/draft/issues/new?template=bug_report.md)
- **Features:** Use the [feature request template](https://github.com/drafthq/draft/issues/new?template=feature_request.md)
- **Security:** See [SECURITY.md](SECURITY.md)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

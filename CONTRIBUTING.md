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
3. Add the skill name to the `SKILL_ORDER` array in `scripts/lib.sh`, then add a case entry in `get_skill_header()` AND `get_copilot_trigger()` in `scripts/build-integrations.sh`
4. Run `make build && make test`
5. Add the command to `README.md`
6. Add a test if the skill has validatable behavior

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

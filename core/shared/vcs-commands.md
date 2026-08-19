# VCS Command Abstraction

Shared procedure for VCS write operations across all Draft skills. Draft is GitHub-first and uses the standard `git` CLI throughout.

Referenced by: All skills that execute VCS write operations (`/draft:implement`, `/draft:revert`, `/draft:new-track`).

## Standard Operations

| Operation         | Command                                  |
|-------------------|------------------------------------------|
| Stage files       | `git add <files>`                        |
| Remove files      | `git rm <files>`                         |
| Commit            | `git commit -m "<message>"`              |
| Reset             | `git reset --soft <ref>`                 |
| Revert            | `git revert --no-commit <sha>`           |
| Checkout branch   | `git checkout -b <branch>`               |
| Pull              | `git pull`                               |
| Push (new branch) | `git push -u origin <branch>`            |
| Push (existing)   | `git push`                               |
| Rebase            | `git rebase <ref>`                       |

### Read Operations

```bash
git diff [options]               # Diff (staged, unstaged, ranges)
git log [options]                # History
git rev-parse [options]          # SHA resolution
git branch --show-current        # Current branch name
git status --porcelain           # Machine-readable status
git ls-files [pattern]           # File listing
git diff --cached --quiet        # Check if anything staged
git rev-list [range]             # Commit listing
```

---

## Commit Message Convention

Draft uses [Conventional Commits](https://www.conventionalcommits.org/) for traceability:

```text
<type>(<track_id>): <description>

[optional body]

[optional footer(s)]
```

Common `<type>` values: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`.

Footer fields (when applicable):

- `Refs: <issue or PR number>` — link to issue tracker
- `Co-Authored-By: <name> <email>` — for AI-assisted commits

If a Jira ticket is linked in `spec.md`, include it in the body or footer:

```text
feat(add-auth): implement OAuth2 callback

Refs: ENG-1234
```

---

## Branch Creation

```bash
git checkout -b <track_id>
```

Track IDs are kebab-case (e.g., `add-user-auth`, `fix-login-bug`). They become the branch name directly.

---

## Push for Review

```bash
git push -u origin <branch>
```

Then open a PR via the `gh` CLI or the GitHub web UI:

```bash
gh pr create --title "<title>" --body "<description>"
```

The PR title should match the track title from `spec.md`. The body should reference the track and include the standard test plan.

---

## Verification Gates

Before any push or PR creation, skills run the project's test/lint commands as defined in `draft/workflow.md` → `## Verification`. Common gates:

- `make test` or `npm test` / `pytest` / `cargo test` — unit tests
- `make lint` or `npm run lint` / `ruff` / `cargo clippy` — static analysis
- `make build` or framework-specific build — type-check / compile

If `workflow.md` does not specify gates, skills detect the test framework via `scripts/tools/detect-test-framework.sh` and use sensible defaults.

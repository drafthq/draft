<<<<<<< HEAD
# Guardrails — dependency-triage (Foundations Stub)

Generalized public Draft baseline. Full ruleset ported from internal systems in subsequent work.
See core/guardrails.md for entry point and loading rules.
=======
# Dependency Vulnerability Triage

Procedure for checking dependency manifests for known vulnerabilities during code review and bug hunting. Applied whenever a change modifies a dependency manifest file (`RC-014`).

**Referenced by:** `/draft:review` Stage 1, `/draft:bughunt`, `/draft:deep-review` Phase 3

**Last updated:** 2026-05-16

---

## Trigger Condition

Run this procedure when a diff or module scan includes changes to any of:

| File | Ecosystem |
|------|-----------|
| `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` | Node.js / JavaScript |
| `requirements.txt`, `pyproject.toml`, `Pipfile`, `Pipfile.lock`, `poetry.lock` | Python |
| `go.mod`, `go.sum` | Go |
| `Cargo.toml`, `Cargo.lock` | Rust |
| `pom.xml`, `build.gradle`, `build.gradle.kts`, `gradle.properties` | JVM (Java, Kotlin, Scala) |
| `Gemfile`, `Gemfile.lock` | Ruby |
| `*.csproj`, `packages.config` | .NET |

Also run during `/draft:deep-review` Phase 3 as a general dependency health check, regardless of whether manifest files changed.

---

## Step 1: Check for Configured Scanner

Read `draft/tech-stack.md` for a `## Security Tooling` or `## Dependency Scanning` section. If a scanner is configured (e.g., Trivy, Snyk, Dependabot), use that. Otherwise, use the ecosystem-default tools below.

---

## Step 2: Run Vulnerability Scan

Execute the appropriate scanner for the detected ecosystem. Use the results as-is — do not modify dependency files as part of review.

| Ecosystem | Command |
|-----------|---------|
| Node.js | `npm audit --json` or `yarn audit --json` |
| Python | `pip-audit --format=json` or `safety check --json` |
| Go | `govulncheck ./...` or `nancy` (pipe `go list -m -json all \| nancy`) |
| Rust | `cargo audit --json` |
| JVM | `./gradlew dependencyCheckAnalyze` or `mvn dependency-check:check` |
| Ruby | `bundle audit check --update` |
| .NET | `dotnet list package --vulnerable` |
| Multi-ecosystem | `trivy fs --scanners vuln .` (if Trivy is installed) |

If the scanner is not installed, note: "Dependency scanner not available — recommend running `<command>` in CI."

---

## Step 3: Classify Findings by CVSS Score

| CVSS Range | Severity in Report |
|------------|-------------------|
| 9.0 – 10.0 | **Critical** — blocks review approval |
| 7.0 – 8.9 | **High** — should fix before merge |
| 4.0 – 6.9 | **Medium** — fix within the next sprint |
| 0.1 – 3.9 | **Low** — note for backlog |

For each finding, report: package name, installed version, fixed version, CVE ID(s), CVSS score, and a one-line description of the vulnerability.

---

## Step 4: Assess Exploitability in Context

Not every CVE applies to a project's actual usage. Before escalating a finding:

1. Check if the vulnerable code path is actually reachable in the project (e.g., a CVE in an XML parser that the project doesn't use in a way that hits the vulnerable path).
2. Check if the project's `draft/tech-stack.md` documents an accepted exception for the package (some transitive deps cannot be upgraded immediately).
3. Check if the CVE is in a `devDependency` / test-only package that never ships to production.

Findings that are not reachable, are in dev-only deps, or have a documented exception in `tech-stack.md` → downgrade by one severity level and note the reason.

---

## Step 5: Report Format

Include a **Dependency Vulnerabilities** subsection in the review or bug report:

```markdown
## Dependency Vulnerabilities [RC-014]

Scanner: <tool used or "not available">
Scan date: <ISO date>

| Package | Installed | Fixed In | CVE | CVSS | Severity | Notes |
|---------|-----------|----------|-----|------|----------|-------|
| lodash | 4.17.4 | 4.17.21 | CVE-2021-23337 | 7.2 | High | Prototype pollution |
| ... | | | | | | |

Critical: N High: N Medium: N Low: N

Recommendation: <upgrade command or note if scanner unavailable>
```

If no vulnerabilities are found, write: "No known vulnerabilities found in direct or transitive dependencies as of <date>."
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c

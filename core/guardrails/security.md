# Security Guardrails

Hard security constraints and reasoning chain for all Draft quality and generation commands. Structured in two parts: **Hard Red Lines** (absolute — no exceptions without an override annotation) and the **Security Reasoning Chain** (5-step process applied to every review).

**Referenced by:** `core/guardrails/review-checks.md` (RC-001, RC-002, RC-003, RC-004, RC-005, RC-006, RC-011), `/draft:review`, `/draft:quick-review`, `/draft:bughunt`, `/draft:deep-review`, `/draft:implement`

**Last updated:** 2026-05-16

---

## Part 1: Hard Red Lines (SEC-01…SEC-10)

These are **absolute**. A violation is always **Critical** severity. The reviewer must not silently pass code that violates a red line.

**Override mechanism:** If a violation is intentional and justified (e.g., a test fixture using an obviously fake key, a local-only dev tool, a legacy path with a filed migration ticket), the developer must add an annotation on the same line or the line above:

```
// SECURITY-OVERRIDE: <ticket-id> <one-line justification>
```

An unannotated violation that cannot be resolved immediately blocks review approval. An annotated override is logged as an **Important** finding (not Critical) with the ticket referenced in the review report.

| ID | Hard Red Line | Detection Signal |
|----|--------------|-----------------|
| SEC-01 | No hardcoded secrets, passwords, API keys, or private keys in source code | `password =`, `api_key =`, `secret =`, `-----BEGIN`, `token =` with non-variable RHS; high-entropy string literals |
| SEC-02 | No `eval`, `exec`, `pickle.load`, `__import__`, `subprocess` with unsanitized user input | Presence of these calls with variables derived from external input |
| SEC-03 | No raw string interpolation in database queries (SQL, NoSQL, search) | Query string construction using `+`, f-strings, `%s` (non-parameterized), template literals inside query builders |
| SEC-04 | No disabled TLS/certificate verification | `verify=False`, `InsecureSkipVerify: true`, `rejectUnauthorized: false`, `ssl._create_unverified_context` in non-test code |
| SEC-05 | No secrets or credentials in log output | Log calls containing `password`, `token`, `secret`, `apikey`, `private_key` as field names or in format strings with actual values |
| SEC-06 | No `shell=True` (or equivalent) with user-controlled input | `subprocess.run(..., shell=True)`, `os.system(user_input)`, backtick execution with external data |
| SEC-07 | No MD5 or SHA-1 for security operations (password hashing, HMAC, signatures) | `hashlib.md5`, `hashlib.sha1`, `MD5Digest`, `SHA1` in auth/crypto paths. Acceptable in non-security checksums with explicit comment. |
| SEC-08 | No wildcard CORS in production endpoints | `Access-Control-Allow-Origin: *` on authenticated endpoints; `cors({ origin: '*' })` without environment gate |
| SEC-09 | No internal stack traces, file paths, or version strings in external API responses | Raw exception objects serialized to HTTP responses; `traceback.format_exc()` in response bodies |
| SEC-10 | No bypassed authentication or authorization checks | New handlers/endpoints without auth middleware invocation and no `// auth: N/A because <reason>` annotation |

---

## Part 2: Security Reasoning Chain

Apply this 5-step chain when reviewing any change that touches authentication, authorization, external input handling, SQL/NoSQL queries, subprocess calls, file I/O, cryptography, serialization, or configuration.

### Step 1: Identify the Security Goal

State what the code is trying to protect:
- Confidentiality (data only accessible to authorized parties)?
- Integrity (data cannot be tampered with)?
- Availability (service cannot be denied or degraded by abuse)?
- Non-repudiation (actions are auditable)?

If the security goal is unclear from context, treat the risk as **High** by default.

### Step 2: Check Hard Red Lines

Run through SEC-01…SEC-10 for every changed file in scope. Flag any violation before continuing to Step 3. Hard red line violations are reported first in the security section, separate from other findings.

### Step 3: Assess Blast Radius

For each finding or suspected vulnerability, state:
- **Who is affected?** (single user, all users of a tenant, all tenants, external parties)
- **What is exploitable?** (read-only data exposure, data modification, code execution, denial of service)
- **How likely is exploitation?** (actively exploited pattern, PoC available, theoretical)

Use blast radius to set severity: `Critical` = full system or multi-tenant impact; `High` = single tenant; `Medium` = limited data exposure; `Low` = theoretical or very limited.

### Step 4: Trace Generative Paths

For code that handles external data, trace from source to sink across these paths:

| Path | What to verify |
|------|---------------|
| **Input validation** | All entry points validate type, length, format, and reject unknown fields |
| **Database queries** | Parameterized or ORM-abstracted; no string interpolation |
| **Credential handling** | Sourced from environment/secrets manager; not logged; not compared with `==` (use constant-time) |
| **Network calls** | TLS enforced; certificates verified; timeouts set |
| **File operations** | Paths sanitized; no path traversal (`../`); permissions checked |
| **Authentication** | Token/session validated; expiry enforced; revocation checked |
| **Output rendering** | User content escaped before HTML/JS rendering |
| **Cryptography** | Algorithms meet minimum key length; IVs are random; no reuse |
| **Logging** | Sensitive fields redacted before write |
| **Subprocess execution** | No shell injection; arguments passed as list, not string |

### Step 5: Classify and Report

For each security finding, report:

```
[SEC finding] <title> [SEC-## or RC-###]
File: path/to/file:line
Blast radius: <single user / tenant / all tenants / full system>
Likelihood: <High / Medium / Low>
Severity: <Critical / High / Medium / Low>
Description: <what is wrong and why it is exploitable>
Fix: <concrete remediation>
Override annotation required: <Yes / No>
```

---

## Part 3: Security Context from Project Files

When applying security analysis, also check these project-specific sources:

- `draft/.ai-context.md` §Security Architecture — intended auth model, trust boundaries, data classification
- `draft/tech-stack.md` — project's auth library, ORM, secrets manager (use these; do not introduce alternatives)
- `draft/guardrails.md` §Hard Guardrails — any project-specific security rules added by the team

Project-level security rules in `draft/guardrails.md` always take precedence over this file.

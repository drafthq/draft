<<<<<<< HEAD
# Guardrails — secure-patterns (Foundations Stub)

Generalized public Draft baseline. Full ruleset ported from internal systems in subsequent work.
See core/guardrails.md for entry point and loading rules.
=======
# Secure Coding Patterns

Language-specific secure coding patterns applied by `/draft:implement`, `/draft:review`, and `/draft:bughunt` when working with security-sensitive code paths. Loaded alongside `core/guardrails/security.md`.

Each section covers the most common failure modes for the language. These are supplementary to the Hard Red Lines in `security.md` — the red lines apply to all languages; these patterns provide language-specific guidance on *how* to satisfy them.

`draft/guardrails.md` project rules take precedence. `core/guardrails.md` C++ rules take precedence for C++ code.

**Last updated:** 2026-05-16

---

## Python

### Credential Handling
- Source secrets from `os.environ` or a secrets manager SDK; never inline. Use `os.environ["KEY"]` not `os.getenv("KEY", "default-secret")` for required secrets.
- Compare password/token with `hmac.compare_digest()` — not `==`. Timing attacks exploit `==` short-circuit evaluation.
- Hash passwords with `bcrypt`, `argon2-cffi`, or `hashlib.scrypt`. Never `hashlib.md5` or `hashlib.sha1` for passwords.

### SQL / Database
- Use the ORM's parameterized API (`cursor.execute("SELECT * FROM t WHERE id = %s", (uid,))`) — never f-strings or `.format()` in query strings.
- Prefer ORM query builders (`User.objects.filter(id=uid)`) over raw SQL unless raw is required for performance with a documented justification.

### Subprocess
- Pass arguments as a list: `subprocess.run(["ls", "-la", path])` — never `subprocess.run(f"ls -la {path}", shell=True)`.
- Validate `path` against an allowlist of acceptable values before any subprocess call that includes it.

### Serialization
- Never `pickle.load()` or `pickle.loads()` on untrusted data. Use JSON or a schema-validated format.
- Validate JSON payloads with a schema (e.g., `pydantic`, `jsonschema`) before accessing fields.

### Logging
- Use `%s` placeholders: `logger.info("user %s logged in", user_id)` — not f-strings (prevents accidental eager evaluation of sensitive objects).
- Apply a sanitize step before logging objects: strip `password`, `token`, `secret`, `key` fields.

---

## Go

### Credential Handling
- Source secrets from environment variables (`os.Getenv`) or a secrets manager. Never hard-code default values that could be production-like.
- Use `subtle.ConstantTimeCompare()` for HMAC or token comparison.
- Use `bcrypt` (`golang.org/x/crypto/bcrypt`) for password hashing.

### SQL / Database
- Use `db.QueryContext(ctx, "SELECT ... WHERE id = ?", id)` with placeholders — never `fmt.Sprintf` in query strings.
- Prefer the project's ORM or query builder if one is established in `draft/tech-stack.md`.

### Subprocess / Exec
- Use `exec.Command("cmd", arg1, arg2)` — not `exec.Command("sh", "-c", userInput)`.
- Validate all file paths with `filepath.Clean` and check the result stays within the expected directory.

### HTTP Clients
- Always set `Timeout` on `http.Client{}`. An infinite timeout enables slow-loris DoS.
- Do not set `InsecureSkipVerify: true` in `tls.Config` outside of test helpers explicitly tagged `// test-only`.

### Logging
- Use structured logging (e.g., `slog`, `zap`, `zerolog`). No `fmt.Println` in production code paths.
- Redact sensitive fields before passing to logger: use a custom `Stringer` or explicit field masking.

---

## TypeScript / JavaScript

### Credential Handling
- Source secrets from `process.env.VAR_NAME`. Never commit `.env` files with real values. Use `.env.example` for documentation.
- Use `crypto.timingSafeEqual()` for comparing secrets.
- Hash passwords with `bcrypt` or `argon2`. Never `crypto.createHash('md5')` for passwords.

### SQL / Database
- Use parameterized queries: `db.query("SELECT * FROM users WHERE id = $1", [userId])` — never template literals in query strings.
- Use the ORM's safe query API (Prisma, TypeORM, Sequelize) — flag raw query usage for review.

### Output Rendering
- Never set `element.innerHTML = userInput` or use `dangerouslySetInnerHTML` with unsanitized data.
- Use `textContent` for text, DOMPurify for HTML that must accept markup.
- In React: JSX text nodes auto-escape; `{userInput}` is safe. `dangerouslySetInnerHTML` is always a flag.

### Subprocess
- Use `child_process.execFile(cmd, [arg1, arg2])` — not `exec(userInput)` or `exec(`cmd ${userInput}`)`.

### Fetch / HTTP
- Never disable TLS in `https.request` options. `rejectUnauthorized: false` in non-test code is SEC-04 violation.
- Set explicit timeouts on all outbound HTTP calls using `AbortController` or library timeout option.

### Logging
- Use the project's structured logger. No `console.log` / `console.error` in production modules.
- Never log `req.body`, `req.headers.authorization`, or any object that may contain credentials directly.

---

## C / C++ (Supplement to `core/guardrails.md`)

The authoritative C++ rules are in `core/guardrails.md` (G1–G8). These are supplementary security-specific patterns.

### Memory Safety
- Validate all buffer sizes before `memcpy`, `strcpy`, `sprintf` — prefer `memcpy_s`, `strncpy`, `snprintf` with explicit size bounds.
- Treat all data from sockets, files, or IPC as untrusted. Validate length fields before using them as loop bounds or allocation sizes.

### String Handling
- Never use `sprintf(buf, format, userInput)` where `format` is user-controlled — format string injection.
- Use `snprintf` with the buffer size always. Check the return value for truncation.

### Integer Safety
- Check for integer overflow before arithmetic used as array index or allocation size.
- Prefer `size_t` for sizes and counts; be explicit about signed/unsigned boundary crossings.

### Subprocess / System Calls
- Never `system(userInput)` or `popen(userInput, "r")`. Use `execve` with explicit argument arrays.
- Sanitize or reject strings containing `;`, `|`, `&`, `$`, `` ` `` before any shell-adjacent API.

---

## Ruby

### Credential Handling
- Source secrets from `ENV['KEY']`. Use `Rails.application.credentials` or `dotenv` for local dev. Never commit secrets.
- Use `ActiveSupport::SecurityUtils.secure_compare` for constant-time token comparison.
- Hash passwords with `bcrypt` (`has_secure_password`). Never MD5 or SHA1 for auth.

### SQL
- Use ActiveRecord query methods: `User.where(id: uid)` — never string interpolation in `where` clauses: `where("id = #{uid}")`.
- Use `sanitize_sql` when raw SQL is unavoidable.

### ERB / Output
- Use `<%= h(user_input) %>` or rely on Rails' automatic HTML escaping. Never `<%= raw(user_input) %>` without sanitization.
- Use `sanitize(html, tags: [...])` (ActionView) when rich text input must be accepted.

---

## Shell / Bash

### Variable Quoting
- Always double-quote variable expansions: `"$VAR"` not `$VAR` — unquoted variables undergo word-splitting and glob expansion.
- Never use `eval "$USER_INPUT"` — use `case`, `[[ ]]`, or named dispatch tables instead.

### Command Injection
- Validate input against a strict allowlist before using in any command: `[[ "$input" =~ ^[a-zA-Z0-9_-]+$ ]]`.
- Prefer passing data through files or environment variables rather than command arguments when handling untrusted content.

### Privilege
- Minimize use of `sudo`; document each use with a comment explaining why it is necessary.
- Avoid `chmod 777`; use the minimum permissions required.

### Secrets
- Never echo secrets to stdout or log files. Redirect sensitive command output to `/dev/null` when the value is not needed.
- Use `read -s` for interactive secret input. Source secrets from files with restricted permissions (`chmod 600`).
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c

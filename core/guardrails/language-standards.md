<<<<<<< HEAD
# Guardrails — language-standards (Foundations Stub)

Generalized public Draft baseline. Full ruleset ported from internal systems in subsequent work.
See core/guardrails.md for entry point and loading rules.
=======
# Language Standards

Per-language code quality and style standards for Draft quality commands. Loaded selectively based on the detected language stack.

**Loading:** `core/shared/draft-context-loading.md` Layer 0.5 specifies which commands load this file. The reviewing command identifies the project language from `draft/tech-stack.md` and applies only the relevant section(s).

**Precedence:** For C/C++ code, `core/guardrails.md` (G1–G8) is the authoritative ruleset — this file's C++ section only supplements it with additional standards not covered by G1–G8. `draft/guardrails.md` project-level rules always take precedence over everything here.

**Last updated:** 2026-05-16

---

## Detecting the Project Stack

Read `draft/tech-stack.md` `## Languages` and `## Primary Language` to identify the stack. Apply:
- The matching section(s) below
- `core/guardrails/secure-patterns.md` for the same language (when in security mode)
- `core/guardrails.md` for C/C++ (always, if C/C++ detected)

---

## C / C++

**Authoritative:** `core/guardrails.md` G1–G8 (object lifecycle, ownership, async safety, type safety, const, test hooks, class design, STL). Apply all of those first.

**Additional standards:**

### Naming
- Classes/structs: `PascalCase`
- Functions and methods: `PascalCase` (matching G2 style conventions for the codebase)
- Local variables and parameters: `snake_case` or `camelCase` — match the file's existing convention
- Constants and macros: `kCamelCase` for constants; `SCREAMING_SNAKE_CASE` for macros (prefer `constexpr` over macros for values)
- Member variables: `snake_case_` with trailing underscore (match existing file style)

### Code Quality
- No `using namespace std;` in header files — pollutes includer's namespace
- No `#define` for magic numbers — use `constexpr` or `enum class`
- Prefer `static_assert` over runtime assertions for compile-time verifiable invariants
- Destructors that release resources must be declared virtual in base classes with virtual functions
- Prefer `std::string_view` over `const std::string&` for read-only string parameters (avoids unnecessary copies)

### Error Handling
- Return error codes or status objects consistently — do not mix exception-based and code-based error handling within the same module
- Log error context before returning an error: function name, relevant IDs, received vs expected values
- Constructor failures: prefer factory functions that return `StatusOr<T>` over throwing constructors

---

## Python

### Naming
- Modules and packages: `snake_case`
- Classes: `PascalCase`
- Functions, methods, variables: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Private members: `_single_leading_underscore` (convention); `__double` only for name mangling

### Code Quality
- Prefer `pathlib.Path` over `os.path` string manipulation for file paths
- Use `dataclasses`, `NamedTuple`, or `TypedDict` for structured data — avoid bare dicts for complex schemas
- `f-strings` for formatting in Python 3.6+; no `.format()` or `%` formatting in new code unless the context requires it (logging — see below)
- Avoid mutable default arguments: `def foo(items=[])` → `def foo(items=None): items = items or []`
- Prefer explicit exception types over bare `except:` or `except Exception:` — catch what you can handle
- Use type annotations (`typing` module or built-in generics in 3.10+) for all public function signatures

### Error Handling
- Raise specific exception subclasses with a message that includes context (what was expected, what was received)
- Use `contextlib.suppress` only for truly ignorable errors — never suppress `Exception`, `BaseException`, or `OSError` broadly
- Log exceptions with `logger.exception(msg)` (captures traceback) rather than `logger.error(msg)` in exception handlers

### Imports
- Standard library → third-party → local, separated by blank lines (isort convention)
- No wildcard imports: `from module import *` — always import specific names
- No circular imports — restructure to use dependency injection or move shared code to a shared module

---

## Go

### Naming
- Packages: lowercase, single word, no underscores
- Exported identifiers: `PascalCase`
- Unexported identifiers: `camelCase`
- Acronyms: treat as words — `userID` not `userId`; `parseURL` not `parseUrl`; `HttpServer` only if the whole name is an acronym
- Interface names: single-method interfaces use the verb + `-er` suffix: `Reader`, `Writer`, `Closer`

### Code Quality
- Return errors as the last return value; name it `err` in call sites
- Errors are values: construct with `fmt.Errorf("op %s: %w", name, err)` to wrap context
- No panic in library code — only in `main` or clearly documented `Must*` functions
- Use `context.Context` as the first argument of all functions that do I/O, make network calls, or may block
- Prefer table-driven tests with `t.Run` sub-tests over duplicated test functions
- Use `defer` for cleanup (files, locks, connections) immediately after the resource is acquired — not at the end of a long function

### Error Handling
- Always check and propagate errors — no `_ = err` except when semantically correct (e.g., `defer f.Close()` when the write has already succeeded)
- Add context to errors: `fmt.Errorf("loading config from %s: %w", path, err)` — not just re-wrapping
- Distinguish recoverable from terminal errors: use sentinel errors (`var ErrNotFound = errors.New(...)`) for expected conditions that callers handle

---

## TypeScript

### Naming
- Types, interfaces, classes, enums: `PascalCase`
- Variables, functions, methods: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE` for module-level constants; `camelCase` for local
- Files: `kebab-case.ts` for modules; `PascalCase.tsx` for React components (match project convention)

### Code Quality
- Use `unknown` instead of `any` for untyped external data — force narrowing before use
- Prefer `readonly` for arrays and object properties that should not be mutated
- Use `interface` for object shapes that may be extended; `type` for unions, intersections, mapped types
- Prefer strict null checking — no `!` (non-null assertion) unless you have a comment explaining why it is safe
- Use `satisfies` operator (TS 4.9+) to validate literal objects against a type without widening
- Never use `// @ts-ignore` — use `// @ts-expect-error: <reason>` with a specific reason, or fix the type

### Error Handling
- Use discriminated union result types for expected failure paths: `{ ok: true; value: T } | { ok: false; error: string }` — not throwing for control flow
- Do not swallow errors in `catch` blocks — at minimum log with context before continuing
- `async/await` over `.then().catch()` chains for readability; always `await` or explicitly handle the returned promise

---

## JavaScript (Non-TypeScript)

All TypeScript naming and error handling standards apply. Additionally:

- Document expected types with JSDoc `@param {string}`, `@returns {Promise<User>}` on all public functions
- Use `===` for all equality — never `==`
- No `var` — use `const` by default, `let` only when reassignment is needed
- Use optional chaining `?.` and nullish coalescing `??` over manual null guards

---

## Ruby

### Naming
- Classes, modules: `PascalCase`
- Methods, variables: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Predicates (return boolean): end with `?`: `valid?`, `empty?`
- Dangerous methods (mutate receiver or raise): end with `!`: `save!`, `update!`

### Code Quality
- Prefer `frozen_string_literal: true` at the top of every file
- Use `Kernel#pp` only in development — never in production code
- Prefer `map`, `select`, `reject`, `reduce` over imperative loops for collections
- Use `Struct` or `Data.define` (Ruby 3.2+) for value objects instead of hash literals with known keys
- Avoid `rescue Exception` — rescue specific error classes

### Error Handling
- Raise with a descriptive message: `raise ArgumentError, "expected positive integer, got #{value.inspect}"`
- Use `rescue => e; log_error(e); raise` when catching and re-raising — never silently swallow
- In Rails: use `rescue_from` in controllers to handle expected error types centrally

---

## Rust

### Naming
- Structs, enums, traits: `PascalCase`
- Functions, methods, variables, modules: `snake_case`
- Constants and statics: `SCREAMING_SNAKE_CASE`
- Type parameters: single capital letters (`T`, `E`) or short `PascalCase` names

### Code Quality
- Use `Result<T, E>` for fallible operations; `Option<T>` for optional values — never `unwrap()` or `expect()` in library code (acceptable in tests and `main`)
- Prefer `?` operator for early error return over explicit `match`/`if let` for errors
- Use `thiserror` for library error types; `anyhow` for application-level error aggregation
- Follow ownership conventions: pass `&T` for read-only, `&mut T` for mutation, `T` to transfer ownership
- Clippy clean: all new code must pass `clippy::all` or document exceptions with `#[allow(clippy::rule_name)] // reason`

### Error Handling
- Error types must implement `std::error::Error` — use `thiserror::Error` derive
- Add context at each call site: `.context("reading config file")`, `.with_context(|| format!("processing record {id}"))`
- Never `panic!` in library code — convert to `Result`

---

## Shell / Bash

### Style
- Script header: `#!/usr/bin/env bash` and `set -euo pipefail` on the second line — no exceptions
- Function names: `snake_case`
- Variable names: local variables `snake_case`; exported/global variables `SCREAMING_SNAKE_CASE`
- Constants: `readonly CONSTANT_NAME="value"`

### Code Quality
- Always quote variable expansions: `"$var"` — unquoted variables are a common source of bugs
- Use `[[ ]]` for conditionals over `[ ]` — safer, more predictable
- Use `$(command)` for command substitution over backticks
- Check exit codes of critical commands: `if ! cmd; then ... fi` or `cmd || die "msg"`
- No `which` to find executables — use `command -v` instead
- `set -e` alone is not enough — always pair with `set -u` (unset variables as errors) and `set -o pipefail`

### Error Handling
- Define a `die()` function: `die() { echo "ERROR: $*" >&2; exit 1; }` and use it for all fatal errors
- Print errors to stderr (`>&2`), normal output to stdout
- Trap `ERR` and `EXIT` for cleanup: `trap cleanup EXIT`
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c

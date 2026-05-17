# C++ Hard Guardrails — Systems Programming

> **See also:** [`core/guardrails/README.md`](guardrails/README.md) for the full rule reference (SEC/CQ/DN/RC IDs) and precedence. This file contains the C++-specific `G1.x..G7.x` rules and is loaded for C/C++ projects only. For non-C++ language standards, see [`core/guardrails/language-standards.md`](guardrails/language-standards.md).

Mandatory guardrails for C++ systems code at . All Draft quality commands (`/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:implement`, `/draft:debug`, `/draft:assist-review`) **must** enforce these rules. Violations are always flagged — no exceptions.

These guardrails are pre-seeded into every project's `draft/guardrails.md` by `/draft:init` and loaded at runtime via `core/shared/draft-context-loading.md`.

**Source:** C++ Pitfalls and General Guidelines (internal).

---

## G1 — Object Lifecycle & Memory Safety

### G1.1: No temporary strings in Printf-style trace APIs

Passing `.c_str()` of a temporary (e.g., `proto.ShortDebugString().c_str()`) to `Printf`-style APIs that store format arguments by reference creates a dangling pointer. The temporary is destroyed at the end of the statement; the stored pointer becomes invalid.

- **Wrong:** `mem_tracer_->Printf("Bug: %s", my_proto->ShortDebugString().c_str());`
- **Fix:** Use `Print(StringPrintf(...))` when arguments include short-lived `.c_str()` pointers.

### G1.2: No dangling references after object destruction

Never hold references or raw pointers to members of an object that may be destroyed before the reference is used. This includes captured `this`, member pointers stored in callbacks, and iterator references across async boundaries.

### G1.3: No capture-all-by-reference in async lambdas

Capturing local variables by reference (`[&]`) in a lambda that may execute asynchronously (e.g., as a `done_cb` of another op) creates use-after-free when the enclosing scope exits before the callback fires.

- **Fix:** Capture by value, use `shared_ptr`, or explicitly list captures.

### G1.4: Every async functor must be wrapped with callback_muter

A functor that accesses op members and may fire after the op is destroyed must be wrapped with `callback_muter_->Wrap()`. Omitting this causes use-after-free.

### G1.5: Never wrap op's own done_cb in ClosureRunner when extracting result via raw pointer

When extracting a result from an op using its raw pointer inside the op's own done callback, that callback must NOT be wrapped in a ClosureRunner. The ClosureRunner may destroy the op before the raw-pointer access, causing use-after-free.

```cpp
// CORRECT — no ClosureRunner on op_done_cb
auto op = SomeOp::CreatePtr();
op_done_cb = [raw_op = op.get()] { error = raw_op->error(); };
op->Start(op_done_cb);
```

### G1.6: ClosureRunner and CallbackMuter must be wrapped in correct order

The correct order is: `callback_muter_->Wrap()` first, then `cr_->Wrap()`. Reversing the order breaks cleanup semantics.

### G1.7: Every async functor must be wrapped with cr_

Omitting `cr_->Wrap()` on a functor can cause: (a) the op finishing in the wrong ClosureRunner triggering CHECK failures, or (b) stack overflow when control flow becomes too deep.

### G1.8: No op member access after potential op destruction in loops

If `DoWork(ii)` may destroy the op on the last iteration, the loop's subsequent access to op members (e.g., `count_`, `disk_id_set_`) is use-after-free.

- **Wrong:** `for (int ii = 0; ii < count_; ++ii) DoWork(ii);` — if last iteration destroys op, `count_` access is UB.
- **Fix:** Copy loop bounds to a local variable before the loop, or restructure to avoid self-destruction mid-loop.

### G1.9: No code execution after Finish()

After calling `Finish()`, the op may be destroyed. Any code executing after `Finish()` on the same path accesses a potentially destroyed object.

- **Always** `return` immediately after `Finish()`.
- In conditional blocks: add `return` even if the method appears to end after the block — guards against future code additions.

### G1.10: No unintended deep copies via auto

Using `auto` with map subscript returns a copy, not a reference:

- **Wrong:** `auto my_proto = map_[key];` — deep-copies the value.
- **Fix:** `auto& my_proto = map_[key];` or `const auto& my_proto = map_.at(key);`

### G1.11: std::move discipline

- **Always move** objects expensive to copy (large strings, protocol buffers) when the source is no longer needed.
- **Never use** an object after it has been moved — this may trigger SEGV or undefined behavior.

### G1.12: No shared_ptr binding to non-trivial objects in callbacks

Binding `shared_ptr` to objects that hold EventDriver/ThreadPool references in callbacks creates circular references. The destructor runs inside the pool's own thread, causing deadlock or undefined behavior.

- **Fix:** Bind raw pointers in the lambda and wrap with `callback_muter_` of the bound object.

---

## G2 — Concurrency & Locking

### G2.1: No mutable operations under shared (read) locks

Calling mutable methods while holding a shared/read lock violates lock semantics and causes data races.

- **Wrong:** `ScopedSpinLocker ssl(&sl_, false /* is_exclusive */); lru_cache_->Lookup(...);` (if Lookup mutates internal state)
- **Fix:** Use exclusive lock for any operation that modifies state.

### G2.2: Always release spinlock before invoking callbacks

A callback may synchronously re-acquire the same spinlock, causing deadlock.

- Release the lock explicitly before invoking any callback or `Finish()`.
- Use `ScopedSpinLocker::RegisterReleaseOrDestructionCallback()` when appropriate.
- **Corollary:** Always release spinlocks synchronizing owner-object state before calling `Finish()`, because `Finish()` may invoke a `done_cb` that creates another op acquiring the same lock — all synchronously.

### G2.3: No object destruction under spinlock protection

Destroying expensive objects (large protocol buffers, complex data structures) while holding a spinlock causes contention.

- **Wrong:** `auto sl = sl_.GetScopedLocker(); lru_cache_.Insert(xx, yy);` — evicted objects destroyed before lock release.
- **Fix:** Capture evicted objects, release lock, then let them destruct.

### G2.4: Never sacrifice correctness for lock "optimization"

Performing operations on shared member variables without locking to "optimize" around G2.3 is far more dangerous than the contention it avoids. Always choose correctness over performance when unsure of side-effects.

### G2.5: No synchronous waits in async code paths

Mixing `Trigger::Wait()` or other blocking synchronous primitives in otherwise asynchronous (e.g., networking) code can cause deadlock when all threads enter the wait state.

---

## G3 — Control Flow & Error Handling

### G3.1: Always return after Finish() in conditional blocks

If `Finish()` is called inside an `if`/`else` or any conditional block, always add `return` — even if the method appears to end after the block. This protects against someone adding code after the block without noticing the `Finish()` call.

### G3.2: CHECKs are for internal consistency only

- CHECKs assert internal invariants where forward progress is impossible if violated (e.g., corrupt data structure).
- External systems can always provide bad data — these must NOT be CHECKs. Use error handling and propagation.
- Non-null pointer assertions must be CHECKs (not DCHECKs) — a FATAL is easier to debug than a SIGSEGV.

### G3.3: DCHECKs must not contain side-effecting expressions

`DCHECK(some_map.erase("key"))` — the erase does not execute in release builds. Never put actual logic inside DCHECK.

- **Fix:** Execute the operation separately, then DCHECK the result.

### G3.4: DCHECK vs CHECK vs LOG(DFATAL) selection

| Scenario | Use |
|----------|-----|
| Internal consistency, forward progress impossible | `CHECK` |
| Expensive consistency check, debug-only | `DCHECK` |
| Fail in debug, log-and-continue in release | `LOG(DFATAL)` |
| External input validation | Error handling (never CHECK) |

---

## G4 — Format & API Correctness

### G4.1: Printf format strings must match argument types

Format specifier / argument type mismatches (e.g., `%s` for `int`, `%d` for `const char*`) cause undefined behavior. Verify every `Printf`-style call matches specifiers to argument types.

### G4.2: MemTracer Print vs Printf selection

| Situation | API | Reason |
|-----------|-----|--------|
| Format string with non-pointer args | `Printf` | Lazy construction — string built only when tracer is rendered |
| Argument includes `.c_str()` of a stack variable | `Print(StringPrintf(...))` | Avoids dangling pointer — string is materialized immediately |
| Long literal string | `Printf` with format | Avoids N copies of the string across tracer objects |
| Dynamic string variable | `Print(str)` | Avoids `Printf(str.c_str())` dangling-pointer trap |

### G4.3: Use Maybe-prefixed MemTracer variants when op may be finished

- Use `MaybePrint`/`MaybePrintf` when the code path may execute after `Finish()` (e.g., `ReleaseLock` called from destructor as fail-safe).
- Do NOT use Maybe variants when the code is not expected to run post-Finish — it suppresses the DCHECK that catches unexpected execution.

### G4.4: String + integer does not concatenate

`"foo: " + integer` performs pointer arithmetic, not string concatenation. GCC does not warn. Use `StringPrintf` or `absl::StrCat`.

### G4.5: boost::optional<bool> tests presence, not value

`if (xx)` where `xx` is `boost::optional<bool>` tests whether `xx` is *set*, not whether the contained value is `true`. Use `if (xx && *xx)` or `if (xx.value_or(false))` to test the value.

---

## G5 — GFlags & Runtime Configuration

### G5.1: Snapshot gflag values at op start

A gflag may be flipped between two reads in the same op. Code like `if (FLAGS_xxx) DoStuff(); ... if (FLAGS_xxx) CHECK(StuffDone)` breaks if the flag changes between the two reads.

- **Fix:** Read the flag once into a local variable at op start and use the local throughout.

---

## G6 — Performance

### G6.1: Avoid ByteSize() on proto objects in hot paths

`ByteSize()` is expensive on protocol buffer objects. Cache the result if needed multiple times, or avoid calling it in tight loops.

### G6.2: Prefer repeated fields over map fields in proto for serialization-sensitive paths

Proto `map` fields are costlier than `repeated` fields for serialization and deserialization.

### G6.3: No inline execution in SpawnWorkersAndJoin done_cb

When using `ClosureUtil::SpawnWorkersAndJoin`, do not wrap the `done_cb` with `true /* can_execute_inline */`. This causes hard-to-debug correctness issues. Only use inline execution in performance-critical code where correctness has been verified.

---

## G7 — Op Refresh

### G7.1: Op refresh method selection

| Method | Behavior | Risk |
|--------|----------|------|
| Timestamp refresh | Updates timestamp, op stays alive | None |
| Finish-and-reissue | Marks finished, gets new op id | May break GC correctness |

- Use `MaybeRefreshOperationId` for self-refresh.
- Use `AddOpIdRefreshListener` on child ops for parent notification.
- In snap_tree, snap_fs, and below: never use finish-and-reissue.

---

## Enforcement

All Draft commands must:

1. **Load** this file (via `core/guardrails.md` inlined at runtime) alongside the project's `draft/guardrails.md`.
2. **Flag** any violation of these guardrails in C++ code as a finding with the guardrail ID (e.g., `G1.3`, `G2.2`).
3. **Classify** violations using standard severity:
   - **Critical:** Use-after-free, data race, deadlock (G1.x, G2.1–G2.5)
   - **High:** Incorrect CHECK/DCHECK usage, missing return after Finish (G3.x)
   - **Medium:** Performance pitfalls, API misuse (G4.x, G5.x, G6.x)
4. **Never suppress** these guardrails. They are not subject to learned-convention overrides.
5. **Cross-reference** with `draft/guardrails.md` project-level entries for additional context.

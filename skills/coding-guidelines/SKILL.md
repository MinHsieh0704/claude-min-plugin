---
name: coding-guidelines
description: Universal coding guidelines that reduce common LLM coding mistakes - think before coding, simplicity first, surgical changes, goal-driven execution, security, dependency awareness, regression awareness, explaining non-obvious decisions, failing loudly, and context sync before long tasks. Read this before writing or modifying code in any language or stack.
---

# Coding Guidelines

Universal behavioral guidelines to reduce common LLM coding mistakes. These rules apply across all projects and tech stacks.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks (typo fixes, single-line changes), use judgment.

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Self-check: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

Test: Every changed line should trace directly to the user's request.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria allow independent iteration. Weak criteria ("make it work") require constant clarification.

---

## 5. Security Is Non-Negotiable

**Regardless of task triviality, the following lines must not be crossed.**

- Never hardcode secrets: API keys, passwords, tokens, credentials must use environment variables or a secret manager.
- Treat all external input as untrusted: SQL, shell commands, and HTML output must be properly escaped or parameterized.
- Do not implement crypto algorithms by hand — use standard library / vetted packages.
- When changes touch authentication, authorization, or data persistence, flag it explicitly and wait for confirmation.
- If you spot an existing security vulnerability: mention it, do not silently fix it (see Guideline 3).

---

## 6. Dependency Awareness

**Adding a new dependency is a decision, not a default.**

Before introducing a new package:
- Confirm the need cannot be met by the standard library.
- State the reason, version, and license type explicitly.
- Do not upgrade existing dependencies unless explicitly asked.
- Avoid packages that are unmaintained, low-download, or have known CVEs.
- Be aware of transitive dependency risks.

---

## 7. Regression Awareness

**Your changes must not silently break things elsewhere.**

Before submitting changes, consciously consider:
- Which downstream callers or modules does this affect?
- Have you changed a function signature, return type, or side-effect behavior?
- Have you changed an implicit contract (e.g., previously idempotent, now not)?

When regression risk exists, label it explicitly:
```
[Regression Risk] This change modifies the return shape of X.
The following call sites need verification:
- module/file_a.ext:42
- module/file_b.ext:87
```

---

## 8. Explain Non-Obvious Decisions

**The code is done, but the decision process must not be a black box.**

Proactively explain in the following cases:
- Why option A was chosen over option B.
- Use of a non-obvious algorithm or data structure.
- Deliberate non-handling of an edge case (and why).
- Code that "looks like it could be shorter" but is intentionally not.

Inline note format:
```
// Using Map instead of plain object: preserves insertion order,
// needed for deterministic output in tests.
```

---

## 9. Fail Loudly, Not Silently

**Bad silence is harder to debug than obvious errors.**

- Do not swallow exceptions (`catch (e) {}`) without logging or rethrowing.
- Do not silently return defaults on anomalous data unless explicitly specified.
- Error messages must include enough context (what, where) — not just `"Error occurred"`.
- Do not use `any` or type assertions (`as X`) to mask type errors without justification.

---

## 10. Context Sync Before Long Tasks

**For long tasks, confirm alignment before starting.**

Tasks with more than 3 steps or touching more than 3 files require a plan first:

```
Plan:
1. Modify auth.ts -> add token refresh logic -> verify: unit tests pass
2. Update api.ts -> intercept 401 and trigger refresh -> verify: integration tests pass
3. Remove direct localStorage token reads -> verify: no regression

Proceed?
```

Do not start execution before the user confirms.

---

## When These Guidelines Are Working

You will observe:
- Fewer unnecessary changes in diffs.
- Fewer rewrites due to overcomplication.
- Clarifying questions arriving before implementation, not after mistakes.
- Security and regression issues caught at proposal time, not in code review.

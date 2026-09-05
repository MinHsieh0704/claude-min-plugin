---
name: coding-guidelines
description: Universal coding guidelines that reduce common LLM coding mistakes - think before coding, simplicity first, surgical changes, goal-driven execution, security, dependency awareness, regression awareness, explaining non-obvious decisions, failing loudly, and context sync before long tasks. Read this before writing or modifying code in any language or stack.
---

# Coding Guidelines

Universal behavioral guidelines to reduce common LLM coding mistakes. These rules apply across all projects and tech stacks.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks (typo fixes, single-line changes), use judgment.

---

## 1. Think Before Coding
<!-- summary: don't assume, don't hide confusion, surface tradeoffs; any set of options you offer must include one that does less; if something is unclear, stop and ask. -->

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- **Any set of options you offer must include one that does less** — remove something, simplify, or don't do it at all. A menu where every option adds has already answered the question, and it answers it before anyone has gone looking for the simpler approach the bullet above asks for.
- If something is unclear, stop. Name what's confusing. Ask.

---

## 2. Simplicity First
<!-- summary: the minimum code that solves the problem; nothing speculative, no abstractions for single-use code, no branch for a case that cannot reasonably occur - where that collides with 9, 2 wins, and you leave one comment line saying the case is not handled. -->

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- **When this collides with guideline 9** — a loud failure for a case that cannot reasonably occur — **this one wins**: one comment line saying the case is not handled, not a branch that handles it.
- If you write 200 lines and it could be 50, rewrite it.

Self-check: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

---

## 3. Surgical Changes
<!-- summary: touch only what you must, match existing style, and clean up only the orphans your own change created. -->

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
<!-- summary: turn the task into verifiable success criteria and loop until they pass; where the task sets a size or review budget, spending it also ends the loop - then report rather than open another round. -->

**Define success criteria. Loop until verified — within the budget the task set.**

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

**The loop has an end.** When the task carries a size or review budget, spending it ends the loop: report what is still unverified and by how much the budget was missed, and do not open another round. A criterion that can always be made stricter is not a criterion, it is a direction.

---

## 5. Security Is Non-Negotiable
<!-- summary: never hardcode secrets, treat all external input as untrusted, never hand-roll crypto; flag any change touching auth, authorization, or persistence. -->

**Regardless of task triviality, the following lines must not be crossed.**

- Never hardcode secrets: API keys, passwords, tokens, credentials must use environment variables or a secret manager.
- Treat all external input as untrusted: SQL, shell commands, and HTML output must be properly escaped or parameterized.
- Do not implement crypto algorithms by hand — use standard library / vetted packages.
- When changes touch authentication, authorization, or data persistence, flag it explicitly and wait for confirmation.
- If you spot an existing security vulnerability: mention it, do not silently fix it (see Guideline 3).

---

## 6. Dependency Awareness
<!-- summary: a new dependency is a decision, not a default; state the reason, version, and license. -->

**Adding a new dependency is a decision, not a default.**

Before introducing a new package:
- Confirm the need cannot be met by the standard library.
- State the reason, version, and license type explicitly.
- Do not upgrade existing dependencies unless explicitly asked.
- Avoid packages that are unmaintained, low-download, or have known CVEs.
- Be aware of transitive dependency risks.

---

## 7. Regression Awareness
<!-- summary: name the downstream callers and changed contracts your edit affects before submitting. -->

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
<!-- summary: say why A over B in one sentence, and why code that looks shortenable intentionally is not; measurements and longer arguments go to a references file. -->

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

**One sentence per decision.** A measurement, or an argument longer than that, goes into a references file the note points at; the note itself carries the conclusion and the number. A file where a quarter of the lines explain the other three quarters has moved the complexity, not removed it.

---

## 9. Fail Loudly, Not Silently
<!-- summary: no empty catch blocks, no silent defaults on anomalous data, no type assertions masking real errors. -->

**Bad silence is harder to debug than obvious errors.**

- Do not swallow exceptions (`catch (e) {}`) without logging or rethrowing.
- Do not silently return defaults on anomalous data unless explicitly specified.
- Error messages must include enough context (what, where) — not just `"Error occurred"`.
- Do not use `any` or type assertions (`as X`) to mask type errors without justification.

---

## 10. Context Sync Before Long Tasks
<!-- summary: more than 3 steps or more than 3 files: state the plan and get confirmation before starting. -->

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

## 11. Fix the Cause, Not the Symptom
<!-- summary: group a batch of review findings by root cause before fixing any, since deleting the construct they share beats guarding each one; when one thing keeps breaking or a fix costs a regression elsewhere, the spec is the suspect, not the code. -->

**Repetition is evidence. Read it before writing another guard.**

- **Given a batch of review findings, group them by root cause before fixing any of them.** Several findings usually share one construct, and deleting that construct is a smaller change than adding a guard for each finding it produced. Working down the list in order hides the grouping, because each finding on its own reads as "something is missing here".
- **When one thing keeps breaking, or fixing A breaks B, stop asking how to fix it and ask whether the spec is wrong.** Repeated defects in one place, and a fix that costs a regression somewhere else, are both evidence about the requirement rather than about the code — and "how do I fix this" is a question that never reaches that. Two answers are legitimate and a third is not: change the spec, or drop the case and **write down that it is not supported**. Patching again is the one that is not, because each round adds a guard, and the guards are what the next round breaks.

Self-check: "Am I about to add another guard to the same construct?" If yes, delete the construct
or change the spec.

---

## When These Guidelines Are Working

You will observe:
- Fewer unnecessary changes in diffs.
- Fewer rewrites due to overcomplication.
- Clarifying questions arriving before implementation, not after mistakes.
- Security and regression issues caught at proposal time, not in code review.

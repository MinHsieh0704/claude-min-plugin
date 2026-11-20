---
name: coding-guidelines
description: Universal coding guidelines that reduce common LLM coding mistakes - think before coding, simplicity first, surgical changes, verifying APIs instead of recalling them, goal-driven execution, never claiming unrun verification, security, dependency awareness, regression awareness, explaining non-obvious decisions, failing loudly, context sync before long tasks, and fixing the cause rather than the symptom. Read this before writing or modifying code in any language or stack, and when addressing code review findings or repeated bug fixes.
---

# Coding Guidelines

Universal behavioral guidelines to reduce common LLM coding mistakes. These rules apply across all projects and tech stacks.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks (typo fixes, single-line changes), use judgment.

**Cross-references in this file use guideline names, not numbers.** Numbers change when guidelines are added or reordered; names do not.

---

## Interaction Mode
<!-- summary: every "ask", "stop", or "wait for confirmation" below means exactly that when the user is present; when running non-interactively, take the most conservative reading, state the assumption, and skip and report any irreversible, security-boundary, or unverifiable-API step instead of blocking. -->

**This section governs every guideline below that says "ask", "stop", or "wait for confirmation".** No guideline handles this on its own.

- **User present:** do exactly what the guideline says — ask, stop, or wait.
- **Non-interactive** (CI, scheduled job, background agent): do not block on a confirmation nobody can give.
  - Take the most conservative reading of the request and state that assumption in your output.
  - Skip any step that is irreversible or moves a security boundary, and report it as skipped with the reason. Writing code that performs an irreversible action is not itself irreversible; executing it is.
  - Skip any step blocked because an API cannot be verified (see "Verify APIs, Don't Recall Them"), and report it. Never write it speculatively.
  - Continue with everything else.

---

## 1. Think Before Coding
<!-- summary: don't assume, don't hide confusion, surface tradeoffs; any set of options you offer must include one that does less; if something unclear would materially change the output, stop and ask; otherwise state the assumption and proceed. -->

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State assumptions explicitly. Ask only when the ambiguity would materially change the output; otherwise state the assumption and proceed.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- **Any set of options you offer must include one that does less** — remove something, simplify, or don't do it at all. A menu where every option adds has already answered the question, and it answers it before anyone has gone looking for the simpler approach the bullet above asks for.

---

## 2. Simplicity First
<!-- summary: the minimum code that solves the problem; nothing speculative, no abstractions for single-use code, no branch for a case that cannot reasonably occur - where that collides with "Fail Loudly, Not Silently", this one wins, and, where a reader would expect handling, you leave one comment line saying the case is not handled. -->

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- **When this collides with "Fail Loudly, Not Silently"** — a loud failure for a case that cannot reasonably occur — **this one wins**: one comment line saying the case is not handled, not a branch that handles it. Add that comment only where a reader would otherwise expect handling.
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

## 4. Verify APIs, Don't Recall Them
<!-- summary: a third-party or version-sensitive API you remember is not one that exists; read the installed source, the version-pinned docs, or --help before using any such symbol you have not seen in this repository. Stable standard-library APIs available in the project's minimum supported runtime are exempt. -->

**A function you remember is not a function that exists.**

**Scope:** third-party package APIs, version-sensitive APIs, CLI flags, config keys, and environment variables. Stable language standard libraries (`JSON.parse`, `os.path.join`) are exempt, but only for APIs available in the project's minimum supported runtime - check `engines`, `python_requires`, or the equivalent. Newer standard-library additions (Node's global `fetch`, Python's `itertools.batched`) are version-sensitive and in scope.

- Before using any in-scope symbol you have not seen in this repository, read it from the actual source: the installed package, the version-pinned documentation, or `--help`.
- **Version matters.** An API that existed in v2 may not exist in the pinned v4. Check the lockfile or manifest for the version actually installed, not the version you remember.
- If you cannot verify it, say so and stop. Do not write plausible code and let the test run find out.

Self-check: "Have I seen this symbol in this repository or in its installed dependencies?" If no, go read it.

---

## 5. Goal-Driven Execution
<!-- summary: turn the task into verifiable success criteria and loop until they pass; where the task sets a size or review budget, spending it also ends the loop - then report rather than open another round; without a budget, two consecutive attempts at the same failure that yield no new evidence also end it. -->

**Define success criteria. Loop until verified — within the budget the task set.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

If the project has no test harness, state the verification you will run instead (a script, a curl, a log check); do not add a test framework unasked.

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria allow independent iteration. Weak criteria ("make it work") require constant clarification.

**The loop has an end.** When the task carries a size or review budget, spending it ends the loop: report what is still unverified and by how much the budget was missed, and do not open another round. A criterion that can always be made stricter is not a criterion, it is a direction.

**Default stop when no budget was set:** after two consecutive attempts at the same failure that yield no new evidence (same error, same symptom), stop guessing. Report what was tried, list the specific data needed to continue (log output, config contents, command results), and apply "Fix the Cause, Not the Symptom". Attempts that each surface a different, narrower failure are progress and do not count toward the two.

---

## 6. Never Claim Unrun Verification
<!-- summary: "tests pass" means you ran them and read the output; name every check you skipped and why, and report the relevant failure output verbatim rather than your summary of it. -->

**A check you did not run is not a check that passed.**

- "Tests pass" means you ran them and read the output. Nothing else qualifies.
- If you could not run something — no test runner, no credentials, no network, no database — **say which check was skipped and why**. Do not omit it silently, and do not report it as failed.
- Report the relevant excerpt of the actual failure output verbatim, including file:line, not your summary of what it probably means. A paraphrased stack trace loses the line number that mattered.
- Do not describe an edit as complete when only part of it was applied. Say which parts landed and which did not.

This is the counterpart to "Goal-Driven Execution": that guideline defines the criteria, this one forbids claiming they were met without evidence.

---

## 7. Security Is Non-Negotiable
<!-- summary: never hardcode secrets, treat all external input as untrusted, never hand-roll crypto; flag any change touching auth, authorization, or persistence, and wait for confirmation only when the change moves a security boundary. -->

**Regardless of task triviality, the following lines must not be crossed.**

- Never hardcode secrets: API keys, passwords, tokens, credentials must use environment variables or a secret manager.
- Treat all external input as untrusted: SQL, shell commands, and HTML output must be properly escaped or parameterized.
- Do not implement crypto algorithms by hand — use standard library or vetted packages.
- If you spot an existing security vulnerability: mention it; do not fix it unless asked (see "Surgical Changes").

**Flagging versus waiting** — these are two different strengths, and conflating them makes work in an auth or storage codebase impossible:
- **Always flag**, in your summary, any change that touches authentication, authorization, or data persistence.
- **Wait for confirmation only when the change moves a security boundary**: who can access what, how credentials are validated or stored, what data is retained, or what crosses a trust edge. Routine work inside these modules — a log line, a rename, a test fixture — is flagged, not blocked.

---

## 8. Dependency Awareness
<!-- summary: a new dependency is a decision, not a default; state the reason and the exact version; license, maintenance status, download counts, and known CVEs are checked with a tool or reported as unchecked - never stated from memory. -->

**Adding a new dependency is a decision, not a default.**

Before introducing a new package:
- Confirm the need cannot be met by the standard library.
- State the reason and the exact version explicitly.
- Do not upgrade existing dependencies unless explicitly asked.
- Be aware of transitive dependency risks.

**Package facts are checked, never recalled.** License, maintenance status, download counts, and known CVEs all change between versions and over time. Check them with a tool — the package's LICENSE file or manifest, `npm audit`, `pip-audit`, the registry page — and report what you found. If you did not check, say which ones were not checked. Never state any of them from memory (see "Verify APIs, Don't Recall Them"). Avoid packages the check shows to be unmaintained or carrying known CVEs.

---

## 9. Regression Awareness
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

## 10. Explain Non-Obvious Decisions
<!-- summary: say why A over B in one sentence, and why code that looks shortenable intentionally is not; measurements and longer arguments go in the commit message or PR description. -->

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

**One sentence per decision.** A measurement, or an argument longer than that, goes in the commit message or PR description; the note itself carries the conclusion and the number.

---

## 11. Fail Loudly, Not Silently
<!-- summary: no empty catch blocks, no silent defaults on anomalous data, no type-system escape hatches masking real errors; applies to cases that can occur. -->

**Bad silence is harder to debug than obvious errors.**

- Do not swallow exceptions (`catch (e) {}`, bare `except: pass`) without logging or rethrowing.
- Do not silently return defaults on anomalous data unless explicitly specified.
- Error messages must include enough context (what, where) — not just `"Error occurred"`.
- Do not use type-system escape hatches (`any`, `as X`, `# type: ignore`, `typing.cast`) to mask type errors without a one-line justification.

**Scope:** cases that can occur. For cases that cannot, see "Simplicity First".

---

## 12. Context Sync Before Long Tasks
<!-- summary: plan first when the task changes a public interface, schema, or wire format, or involves migrations, deletions, or anything not trivially reversible; confirmation follows "Interaction Mode". -->

**For consequential tasks, confirm alignment before starting.**

A plan is required when the task:
- changes a public interface, schema, or wire format, **or**
- involves migrations, deletions, or anything not trivially reversible.

Plan format:
```
Plan:
1. Modify auth.ts -> add token refresh logic -> verify: unit tests pass
2. Update api.ts -> intercept 401 and trigger refresh -> verify: integration tests pass
3. Remove direct localStorage token reads -> verify: no regression

Proceed?
```

Wait for confirmation as described in "Interaction Mode".

Below this bar, "Goal-Driven Execution" governs: set the criteria and iterate independently. A plan gate on every task is noise, and noise gets ignored.

---

## 13. Fix the Cause, Not the Symptom
<!-- summary: group a batch of review findings by root cause before fixing any, since deleting the construct they share beats guarding each one; when one thing keeps breaking or a fix costs a regression elsewhere, propose a spec change or documented non-support - the spec is the user's decision. -->

**Repetition is evidence. Read it before writing another guard.**

- **Given a batch of review findings, group them by root cause before fixing any of them.** Several findings usually share one construct, and deleting that construct is a smaller change than adding a guard for each finding it produced. Working down the list in order hides the grouping, because each finding on its own reads as "something is missing here".
- **Deleting a shared construct is within scope when the findings it caused are within scope.** Anything beyond that follows "Surgical Changes".
- **When one thing keeps breaking (the default stop in "Goal-Driven Execution" has fired), or fixing A breaks B, stop asking how to fix it and ask whether the spec is wrong.** Repeated defects in one place, and a fix that costs a regression somewhere else, are both evidence about the requirement rather than about the code — and "how do I fix this" is a question that never reaches that. Two answers are legitimate and a third is not: **propose** changing the spec, or **propose** dropping the case and documenting it as not supported. Both are the user's decision. Patching again is the one that is not legitimate, because each round adds a guard, and the guards are what the next round breaks.

Self-check: "Am I about to add another guard to the same construct?" If yes, propose deleting the construct or changing the spec.

---

## When These Guidelines Are Working

You will observe:
- Fewer unnecessary changes in diffs.
- Fewer rewrites due to overcomplication.
- Clarifying questions arriving before implementation, not after mistakes.
- Security and regression issues caught at proposal time, not in code review.
- Fewer calls to functions that do not exist.
- Completion claims that survive being checked.
- Unattended runs that finish with stated assumptions instead of stalling.

---
name: workflow
description: Create and maintain the three files that carry a task from specification to accepted implementation - TASKS.md (the only formal spec), TASK-CHANGES.md (change proposals awaiting a decision), and REVIEW.md (the result of one review pass). Four subcommands - init, change, decide, review. Use when turning an approved plan into a spec, when a role finds the spec incomplete or contradictory, when recording a review, or when ruling on a pending proposal.
---

# Workflow documents

Three files carry a task from specification to accepted implementation. They exist so the roles
working on that task exchange **artifacts** rather than conversation - whoever implements and
whoever reviews can then run in separate sessions, having read the same spec and neither having
seen the other's reasoning.

| File | What it is | Who writes it |
|---|---|---|
| `.workflow/TASKS.md` | The only formal specification | The coordinator, and only the coordinator |
| `.workflow/TASK-CHANGES.md` | Change proposals awaiting a decision | Anyone may propose, only the coordinator decides |
| `.workflow/REVIEW.md` | The result of one review pass | Whoever performed that review |

**The coordinator is whoever owns the task** - normally the human, or the main session working
directly with them. Implementer and reviewer roles are never coordinators.

They live under `.workflow/` rather than at the repository root so they never collide with a
`TASKS.md` the project already had, and so a reviewer's write whitelist can be drawn as a path
prefix. All three belong in version control. `REVIEW.md` is overwritten on each pass - its history
lives in git, not in accumulated sections.

**Language follows whichever of the three already exists.** Read the ones that are present and write
in the language they use; a task whose spec is in one language and whose review is in another is
harder to read than either. When none exists yet, write English. A reader-based rule cannot settle
this on its own, because these files have two readers at once - the human coordinator and the two
agents - so the first file written decides it for the rest.

**Why the implementer may not edit `TASKS.md`.** A role that can rewrite the spec can lower it,
and the failure looks exactly like success: the spec asks for A, A turns out to be hard, the spec
becomes B, B gets built, B passes review. Nobody lied and nothing is left in the diff to find. So
the spec has one writer and everyone else proposes - that is the whole reason `TASK-CHANGES.md`
exists as a separate file instead of as edits to `TASKS.md`.

## Subcommands

Invoked as `/claude-min-plugin:workflow <subcommand>`. **With no subcommand, list these four and
stop** - never guess which one was meant.

| Subcommand | What it does | Who runs it |
|---|---|---|
| `init` | Turn an approved plan into `.workflow/TASKS.md` | The coordinator |
| `change` | Append the next `TCR-nnn` as `PENDING` | Any role |
| `decide` | Rule on a pending `TCR-nnn` | The coordinator only |
| `review` | Write `.workflow/REVIEW.md` from a review that was performed | Whoever reviewed |

### `init`

Write `.workflow/TASKS.md` from the plan approved in this session - the usual route is plan mode,
approved, then this. When a plan file path is given as a further argument, read that instead.

**Never create the file from a conversation nobody approved.** One `T<n>` section per separately
implementable piece. When `.workflow/TASKS.md` already exists, say so and stop rather than
overwriting a spec that work may already be running against.

### `change`

Append the next `TCR-nnn` to `.workflow/TASK-CHANGES.md` with `Status: PENDING`, creating the file
if it does not exist. Number sequentially from the highest id already present.

**Never edit `TASKS.md` in the same breath** - proposing and deciding are different acts by
different roles. Append only; an existing entry is rewritten for nothing except recording its
decision.

### `decide`

Coordinator only. Set the entry's `Status` and `Decision`.

- `ACCEPTED` - fold the proposed wording into `.workflow/TASKS.md` and append one line to its
  `Change history`.
- `REJECTED` - nothing in `TASKS.md` moves.

Either way the entry stays in the ledger. A rejected proposal is a decision worth being able to
find later, not a mistake to erase.

### `review`

Write `.workflow/REVIEW.md` in the shape below, from the review that was actually performed.
**Never write a verdict for a review that did not run.**

## `.workflow/TASKS.md`

```md
# Tasks

## Goal
One paragraph - what this work is for, in terms of the outcome rather than the implementation.

## Constraints
What must stay true. Compatibility, performance budgets, things that must not change.

## Technical requirements
Language, framework, existing modules to reuse, interface contracts to honour.

## T1 - <short title>
Status: TODO | IN PROGRESS | DONE

### Requirement
What must be true when this is done. Behaviour, not steps.

### Acceptance criteria
- A check that is capable of coming back negative. Name the command where one exists.
- One per line.

### Notes
Anything the implementer would otherwise have to guess. Optional.

## T2 - <short title>
...

## Change history
- TCR-001 accepted 2026-08-25 - added the failure behaviour for missing configuration to T1.
```

**Task ids are `T1`, `T2`, ... and are never reused or renumbered.** They are how a role is pointed
at one piece of work, and how `REVIEW.md` and `TASK-CHANGES.md` refer back; renumbering breaks
every reference that already exists.

**Acceptance criteria carry the weight.** A requirement nobody can check is a requirement two
people will read differently. When a criterion cannot be made checkable, write that down under it -
an acknowledged gap is workable, a vague criterion is not.

## `.workflow/TASK-CHANGES.md`

```md
# Task changes

## TCR-001
Status: PENDING | ACCEPTED | REJECTED
Task: T1
Source: <the role that proposed it>
Created: 2026-08-25

### Reason
What TASKS.md does not say, and how that blocked or misled the work. Point at the exact
requirement or acceptance criterion that is missing, ambiguous, or contradictory.

### Proposed change
The wording to add or replace, concrete enough to be pasted into TASKS.md.

### Impact
What else this touches - behaviour, callers, tests, other tasks.

### Decision
PENDING
```

Three states only. **Propose, then keep working where you can** - a change proposal is not a reason
to stop. Do whatever does not depend on the answer, and say in your report that TCR-nnn is open.

## `.workflow/REVIEW.md`

```md
# Review

Verdict: PASS | FAIL | TASK_UPDATE_REQUIRED
Task: T1
Target: <the diff, branch, commit range, or paths that were reviewed>
Date: 2026-08-25

## TASKS.md compliance
One line per acceptance criterion - met, not met, or cannot judge.

## Findings - manual review
## Findings - /code-review
<Both sections grouped Blocking, then Should fix, then Consider. Every finding anchored to
file:line, with the concrete input or state that triggers it, and the requirement it maps to
or "none". Say plainly when a section found nothing. When /code-review could not be run, say so
and why in its section - never leave it silently empty.>

## Verification
What was actually run and what it printed. Say plainly what could not be run.

## Required fixes
The findings that must be addressed before this can pass, by task id where they map to one.

## TASKS.md update needed?
yes - <TCR ids> | no
```

Keeping the two finding sections apart is what makes the review auditable - `/code-review` is one
input to the pass, not the pass itself, and a reader has to be able to tell which findings a human
process produced.

The three verdicts:

- **`PASS`** - the requirement is met and nothing blocking was found.
- **`FAIL`** - the implementation does not meet the requirement, or something blocking was found.
  The spec is fine, the code is not.
- **`TASK_UPDATE_REQUIRED`** - the code cannot be judged, because `TASKS.md` does not say what
  should happen here. Raise a TCR and return this rather than guessing which side is wrong.

`FAIL` and `TASK_UPDATE_REQUIRED` are genuinely different: one goes back to the implementer, the
other goes back to the coordinator. **Returning `FAIL` where the spec was silent asks somebody to
fix code against a requirement that was never written down.**

This file defines the skeleton, not the findings. How a finding is worded and how severe it is
belong to whoever performed the review.

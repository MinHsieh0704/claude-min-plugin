---
name: workflow
description: Create and maintain the three files that carry a task from specification to accepted implementation - TASKS.md (the only formal spec), TASK-CHANGES.md (change proposals awaiting a decision), and REVIEW.md (a ledger of numbered review findings and the passes that raised them). Four subcommands - init, change, decide, review. Every entry carries a stable id, the files are appended to rather than overwritten, and a coordinator rules on one entry by naming its number. Use when turning an approved plan into a spec, when a role finds the spec incomplete or contradictory, when recording a review, or when ruling on a numbered proposal or finding.
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
| `.workflow/REVIEW.md` | A ledger of review findings, and the passes that raised them | Whoever reviewed, plus the coordinator's rulings |

**The coordinator is whoever owns the task** - normally the human, or the main session working
directly with them. Implementer and reviewer roles are never coordinators.

They live under `.workflow/` rather than at the repository root so they never collide with a
`TASKS.md` the project already had, and so a reviewer's write whitelist can be drawn as a path
prefix. All three belong in version control.

**The two ledgers are appended to, never overwritten.** `TASK-CHANGES.md` and `REVIEW.md` only ever
grow - a later pass adds to what is already there, the only in-place edit is recording a ruling on
an entry that already exists, and no entry is ever deleted. **`TASKS.md` is the exception and is
meant to be**: it is the spec rather than a ledger, the coordinator owns it, and `decide` folds
accepted wording straight into it instead of appending a correction after the thing it corrects.

Overwriting a ledger would make every ruling in it depend on somebody having committed the file
between passes. The coordinator can commit; neither agent can, and nothing in this workflow tells
anyone to - so a ledger that survives only when it happened to be committed does not survive.

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
| `decide` | Rule on a pending `TCR-nnn`, or on an open `F-nnn` | The coordinator only |
| `review` | Append a pass to `.workflow/REVIEW.md` from a review that was performed | Whoever reviewed |

**Every entry in `TASK-CHANGES.md` and `REVIEW.md` carries an id** - `TCR-nnn` for a change
proposal, `F-nnn` for a finding. Ids are allocated from the highest already present in that file,
and are **never reused and never renumbered**, so one id names one thing for the life of the task
and a person can rule on it by saying its number and nothing else.

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

Coordinator only. Rules on one entry, named by its id. Two id namespaces, one verb.

**A `TCR-nnn` in `TASK-CHANGES.md`**:

- `ACCEPTED` - fold the proposed wording into `.workflow/TASKS.md` and append one line to its
  `Change history`.
- `REJECTED` - nothing in `TASKS.md` moves.

**An `F-nnn` in `REVIEW.md`**:

- `FIXED` - it was addressed. Name the commit where there is one.
- `WONTFIX` - a deliberate decision not to act on it.
- `DEFERRED` - real, but not now.

**Set `Status` in place, and append one dated line under `Decision` giving the reason** - never
replace what is already there. `Decision` is a running log, so an entry ruled on more than once
shows every ruling and the order they came in, and a finding that is reopened later still carries
the reasoning that closed it. Nothing else in the entry is rewritten and no entry is ever deleted.
A `REJECTED` proposal and a `WONTFIX` finding are both decisions worth being able to find later,
not mistakes to erase - and until one is written down, the next pass raises the same thing again
with no way to tell that it was already answered.

### `review`

Append a pass to `.workflow/REVIEW.md` in the shape below, from the review that was actually
performed, creating the file if it does not exist. **Never write a verdict for a review that did
not run.**

**Read the findings already in the file before writing any.** A defect you can still reproduce
keeps the `F-nnn` it already has; only something genuinely new takes the next id. Re-raising an old
defect under a new id is how a ruling gets lost and how the same argument gets had twice.

**Reopening.** A finding marked `FIXED` that you can still reproduce goes back to `Status: OPEN`,
with a line appended under its `Decision` naming this pass and what you saw. `WONTFIX` and
`DEFERRED` are the coordinator's calls - leave them exactly where they are however much you
disagree, and put the disagreement in your report instead.

**When `REVIEW.md` is already there in a shape this skill does not describe** - written before these
conventions, or by hand - do not rewrite it and do not give its findings ids. Append the new ledger
below it, with one line saying where the old content ends and why what is above carries no ids. An
id is a promise that somebody verified the thing it names; putting one on a finding you have not
re-verified spends that promise on something you never saw.

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

Two halves. The **findings ledger** is the living register - findings accumulate there, and their
`Status` and `Decision` are the only things `decide` ever touches. The **pass log** under it records
what each review actually did, and never changes once written.

```md
# Review

## Findings - manual review

### F-001
Status: OPEN | FIXED | WONTFIX | DEFERRED
Severity: Blocking | Should fix | Consider
Task: T1 | none
Where: path/to/file.ext:42
Raised: pass 1, 2026-08-25

The defect in one sentence, then the concrete input or state that triggers it and what goes wrong.

Decision:
<absent until the first ruling. One appended line per ruling, newest last - so a finding that was
closed and later reopened still carries the reasoning that closed it.>

### F-002
...

## Findings - /code-review

### F-003
<Same fields.>

## Passes

### Pass 1 - 2026-08-25
Verdict: PASS | FAIL | TASK_UPDATE_REQUIRED
Task: T1
Target: <the diff, branch, commit range, or paths that were reviewed>
code-review: <the level it ran at and what it actually covered> | not run - <why>
Raised: F-001, F-002, F-003 | none
Required fixes: <the F-nnn that must be addressed before this can pass> | none
TASKS.md update needed: yes - <TCR ids> | no

#### TASKS.md compliance
One line per acceptance criterion - met, not met, or cannot judge.

#### Verification
What was actually run and what it printed. Say plainly what could not be run.

### Pass 2 - 2026-08-26
...
```

**Findings sit in id order, oldest first** - append-only and severity-ordered cannot both hold once
a second pass adds a `Blocking` finding below existing `Consider` ones, and of the two, append-only
is the one the rulings depend on. `Severity:` is the field a reader sorts or greps by. Every finding
is anchored to `file:line` with the concrete case that triggers it, and ids are unique across both
sections, so `F-003` names one finding no matter which section it sits in.

Keeping the two finding sections apart is what makes the review auditable - `/code-review` is one
input to the pass, not the pass itself, and a reader has to be able to tell which findings a human
process produced. **When `/code-review` could not be run, that belongs in the pass entry's
`code-review` line, not in this section** - it is a fact about one pass, and a missing pass that
reads as "found nothing" is this step's one failure.

A pass's `Verdict` describes that pass and stays as written. **What is true now is the ledger** -
an open `Blocking` finding is open whatever the last pass concluded.

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

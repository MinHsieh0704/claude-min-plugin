---
name: workflow
description: Create and maintain the three files that carry a task from specification to accepted implementation - TASKS.md (the only formal spec), TASK-CHANGES.md (change proposals awaiting a decision), and REVIEW.md (a ledger of numbered review findings and the passes that raised them). Invoked as /claude-min-plugin:workflow <init | change | decide | review | trim>. Every entry carries a stable id, the files are appended to rather than overwritten, and a coordinator rules on one entry by naming its number. A one-word Rigor level in the spec sets the budgets that let a task end. Use when turning an approved plan into a spec, when a role finds the spec incomplete or contradictory, when recording a review, when ruling on a numbered proposal or finding, or when a ledger has grown too long to read.
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
| `.workflow/REVIEW.md` | A ledger of review findings, and the passes that raised them | Whoever reviewed, the implementer for its own findings, plus the coordinator's rulings |

**The coordinator is whoever owns the task** - normally the human, or the main session working
directly with them. Implementer and reviewer roles are never coordinators.

They live under `.workflow/` rather than at the repository root so they never collide with a
`TASKS.md` the project already had, and so a reviewer's write whitelist can be drawn as a path
prefix. All three belong in version control.

**The two ledgers are appended to, never overwritten.** `TASK-CHANGES.md` and `REVIEW.md` only ever
grow - a later pass adds to what is already there, and the only in-place edit is recording a ruling
on an entry that already exists. **No subcommand ever deletes, renumbers or merges an entry, `trim`
included** - ids are allocated from the highest already present, so a removed entry would hand the
next one an id that already means something else, and the ruling recorded against it would name two
unrelated things. **`TASKS.md` is the exception and is meant to be**: it is the spec rather than a
ledger, the coordinator owns it, and `decide` folds accepted wording straight into it instead of
appending a correction after the thing it corrects.

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

Invoked as `/claude-min-plugin:workflow <subcommand>`. **With no subcommand, list these five and
stop** - never guess which one was meant.

| Subcommand | What it does | Who runs it |
|---|---|---|
| `init` | Turn an approved plan into `.workflow/TASKS.md` | The coordinator |
| `change` | Append the next `TCR-nnn` as `PENDING` | Any role |
| `decide` | Rule on a pending `TCR-nnn`, or on an open `F-nnn` | The coordinator only |
| `review` | Append a pass to `.workflow/REVIEW.md` from a review that was performed | Whoever reviewed |
| `trim` | Shorten every ledger entry without removing any | The coordinator only |

**Two of these are tools, three are formats.** `init` and `trim` do work nobody can do by reading -
call them. `change`, `decide` and `review` describe a shape to write in, and this file is already
in both agents' context through their `skills:` frontmatter, so a role that follows the shape has
used them without invoking anything. **A ledger written to spec by a role that never called
`change` is this working, not failing.** A failure looks different: an entry with no id, a `Status`
overwritten instead of appended to, or a ruling made by someone other than the coordinator.

**Every entry in `TASK-CHANGES.md` and `REVIEW.md` carries an id** - `TCR-nnn` for a change
proposal, `F-nnn` for a finding. Ids are allocated from the highest already present in that file,
and are **never reused and never renumbered**, so one id names one thing for the life of the task
and a person can rule on it by saying its number and nothing else.

### `init`

Write `.workflow/TASKS.md` from the plan approved in this session - the usual route is plan mode,
approved, then this. When a plan file path is given as a further argument, read that instead.

**Offer the `Rigor` level as one non-blocking question** - three options, `low` selected. With
nobody to ask, leave the line out and say so: absent is `low`, so an unattended run cannot grant
itself a larger budget. A task that turns out to need more gets its `Rigor` line raised by the
coordinator, which is an edit anyone can see.

**Never create the file from a conversation nobody approved.** One `T<n>` section per separately
implementable piece. When `.workflow/TASKS.md` already exists, say so and stop rather than
overwriting a spec that work may already be running against - and say what to do instead, because
stopping is not a refusal: **adding `T4` to a live spec is the coordinator editing the file by
hand.** They own it, so that is the normal route rather than a violation. No subcommand appends a
task, because deciding which parts of a plan are new is a judgement, and guessing it wrong
duplicates or drops a requirement with nothing to catch either.

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
- `WONTFIX` - a deliberate decision not to act on it. **This is a normal outcome, not a way of
  hiding work.** It is the expected ruling when the finding falls outside what the spec's `Rigor`
  level or its `Out of scope` list puts in scope, when the triggering situation is rare and costs
  no data, or when the fix would be larger than the harm. A ledger carrying many findings and no
  `WONTFIX` is one where nobody weighed anything.
- `DEFERRED` - real and worth doing, but outside this task's budget.

**Every ruling on an `F-nnn` names its ground in the `Decision` line** - the probability of the
triggering situation, its impact, or the cost of the fix. A ruling that names none of the three is
an assertion, and the next pass has nothing to argue with except the finding itself.

**Set `Status` in place, and append one dated line under `Decision` giving the reason** - never
replace what is already there. `Decision` is a running log, so an entry ruled on more than once
shows every ruling and the order they came in, and a finding that is reopened later still carries
the reasoning that closed it. Nothing else in the entry is rewritten.
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

**Fix your pass number before you write anything, from what the file held when you opened it** - one
past the highest that appears in the pass log or in any finding's `Raised:` line - and stamp every
finding you append with it. An interrupted review leaves its findings and writes no pass entry, so
neither source is authoritative alone. (Why each one fails by itself: `references/design-notes.md`.)

**Reopening.** A finding marked `FIXED` that you can still reproduce goes back to `Status: OPEN`,
with a line appended under its `Decision` naming this pass and what you saw. `WONTFIX` and
`DEFERRED` are the coordinator's calls - leave them exactly where they are however much you
disagree, and put the disagreement in your report instead.

**A review can end the task, and is meant to.** Apply these before writing the pass entry:

- **The review budget is what ends reviewing** - the passes the `Rigor` level allows, or an explicit
  `Review budget`. **Every pass spends one, whatever its verdict** - the budget is the highest pass
  number allowed, so a reviewer knows on opening the file whether it is holding the last one. Each
  level is priced a pass above the fresh reviews it intends, and that spare pass is what confirms a
  returned `FAIL`. A reviewer asked for a pass past the budget says so in its report rather than
  writing one. (Why not severity-based, and why `FAIL` is not exempt: `references/design-notes.md`.)
- **On the last pass the budget allows, recommend a ruling for every finding still `OPEN`** - naming
  the ids and which ruling: `WONTFIX` for anything the level or `Out of scope` put outside scope,
  matching what `decide` calls the expected outcome there, and `DEFERRED` for what is real and worth
  doing but outside this budget. A task cannot be both over and carrying open findings. Recommending
  is as far as this goes - setting a `Status` is `decide`, and `decide` is the coordinator's. A
  reviewer who rules on its own findings has closed its own review.
- **When two consecutive passes each raised findings and the count did not fall, say
  `DIMINISHING RETURNS` on the report's second line**, straight after the verdict. It is a signal to
  the human - narrow the scope or accept the work as it stands - not a verdict, and it does not turn
  `PASS` into `FAIL`. Both counts have to be non-zero, which is also why a first pass never carries
  it.
- **A finding the level or `Out of scope` does not put in scope is `Consider`, and says which of
  the two put it there.** A finding against the test apparatus itself - a fixture, a mutant, a
  harness, a guard on another guard - is outside scope in that sense **unless you can name the
  user-visible failure it lets through**, which takes it back in at the severity that failure
  deserves. (Why the apparatus is capped at all: `references/design-notes.md`.)

**When `REVIEW.md` is already there in a shape this skill does not describe** - written before these
conventions, or by hand - do not rewrite it and do not give its findings ids. Append the new ledger
below it, with one line saying where the old content ends and why what is above carries no ids. An
id is a promise that somebody verified the thing it names; putting one on a finding you have not
re-verified spends that promise on something you never saw.

### `trim`

Coordinator only. Shortens both ledgers without losing anything they record - entries get shorter,
never fewer. Runnable at any point, and neither agent may run it. **Read `references/trim.md` before
running it**: the rules for what shrinks and what is left exactly as it stands are there, and they
are the whole of the subcommand.

## `.workflow/TASKS.md`

```md
# Tasks

## Goal
One paragraph - what this work is for, in terms of the outcome rather than the implementation.

## Constraints
What must stay true. Compatibility, performance budgets, things that must not change.
Rigor: low | medium | high   <- one word; absent means low. It sets the budgets below.
Review budget: <optional override - review passes before the task is done>
Out of scope: <optional additions - situations this task deliberately does not handle, one per line>

## Technical requirements
Language, framework, existing modules to reuse, interface contracts to honour.

## T1 - <short title>

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

**`Rigor` is what lets a task end, and it is one word.** Acceptance criteria say when the work is
*correct*; nothing else says when it is *finished*, and a task carrying only correctness criteria
can always be made more correct. Nobody can state a size cap, a pass count and a list of unhandled
situations before the work exists, so the spec asks for none of them - it asks for one level:

| | `low` (default) | `medium` | `high` |
|---|---|---|---|
| Review budget | 2 passes | 3 | 4 |
| In scope | situations met in normal use, plus any silent loss | also rare situations that fail loudly | every reachable situation |

Two more follow from the level without earning a column each. A finding against the test apparatus
itself is `Consider`, and `Should fix` only at `high` and only where the test guards a past defect.
A test you added must have been run and passed at `low`, and seen to fail before it passed at
`medium` and above.

"Normal use" has a test that needs nobody to answer it: **would a maintainer of this repository hit
the situation within a year of ordinary work?** If not, it is rare. Rare *and silent* - a file
skipped with no trace, a count that reads as clean - is in scope at every level, because silence is
the one failure nothing later catches. Rare *and loud* - the run stops and says why - is out of
scope at `low`. Cosmetic is out of scope everywhere. An explicit `Review budget` or `Out of scope`
line always beats the level.

**A task carries no status field, deliberately.** Whether `T1` is finished is already recorded in
`REVIEW.md` - a pass that returned `PASS` for it with no `OPEN` finding left against it - and a
second copy here would be one nobody maintains, since only the coordinator may write this file and
no subcommand touches a task's status. A field that reads as authoritative and is permanently stale
is worse than no field at all.

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
<absent until ruled on. One appended line per ruling, newest last - the same running log the
findings ledger keeps, so `Status` holds the state and `Decision` holds the reasoning and how it
got there.>
```

Three states only. **Propose, then keep working where you can** - a change proposal is not a reason
to stop. Do whatever does not depend on the answer, and say in your report that TCR-nnn is open.

## `.workflow/REVIEW.md`

Two halves. The **findings ledger** is the living register - findings accumulate there, and their
`Status` and `Decision` are the only things `decide` ever touches. The **pass log** under it records
what each review actually did, and its verdict never changes.

```md
# Review

## Findings

### F-001
Status: OPEN | FIXED | WONTFIX | DEFERRED
Severity: Blocking | Should fix | Consider
Source: manual review | /code-review | implementer
Task: T1 | none
Where: path/to/file.ext:42
Raised: pass 1, 2026-08-25 | implementer, 2026-08-25

The defect in one sentence, then the concrete input or state that triggers it and what goes wrong.

Decision:
<absent until the first ruling. One appended line per ruling, newest last - so a finding that was
closed and later reopened still carries the reasoning that closed it.>

### F-002
...

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
is the one the rulings depend on. `Severity:` and `Source:` are the fields a reader sorts or greps
by. Every finding is anchored to `file:line` with the concrete case that triggers it.

**`Source:` is what makes the review auditable**, and it is a field rather than a section for the
same reason `Severity:` is: one list in id order stays append-only for every writer, while a section
per origin puts the implementer's lower ids below a reviewer's higher ones and turns each later
append into an insert. `/code-review` is one input to a pass rather than the pass itself, and the
implementer files defects found while building rather than reviewing; a reader tells them apart by
grepping the field. **When `/code-review` could not be run, that belongs in the pass entry's
`code-review` line** - it is a fact about one pass, and a missing pass that reads as "found nothing"
is this step's one failure.

**The implementer may append a finding carrying `Source: implementer`, and may do nothing else to
the file**, creating it if it is not there yet, which is the normal case since implementation
usually runs before any review. Without that route a code defect found while building has nowhere
to go but a free-form report, and a report is read once and then gone. A spec gap is a TCR, not a
finding.

Every finding is written with `Status: OPEN`. **`OPEN` is the absence of a ruling, not a ruling** -
writing it is how the entry becomes visible to `decide`, which rules on what is `OPEN`, and to the
next implementer, which works only what is `OPEN`. A finding with no `Status` at all is skipped by
both. Every other value is a ruling and belongs to the coordinator, and so does every `Decision`
line.

A pass's `Verdict` describes that pass and stays as written. **What is true now is the ledger** -
an open `Blocking` finding is open whatever the last pass concluded.

The three verdicts:

- **`PASS`** - the requirement is met, nothing blocking was found, and meeting the requirement
  leaves nothing in `Goal` or `Constraints` unreached. **That last clause is the only thing keeping
  this verdict off the second case below**, which it would otherwise cover as squarely - and it is
  satisfied by default: with no line you can point at, you have met it.
- **`FAIL`** - the implementation does not meet the requirement, or something blocking was found.
  The spec is fine, the code is not.
- **`TASK_UPDATE_REQUIRED`** - the verdict cannot be recorded against `TASKS.md` as it stands:
  either the spec does not say what should happen here, or it says something that misses the `Goal`
  - the code meets its requirement, and meeting that requirement still leaves the stated outcome
  unreached. Raise a TCR and return this rather than guessing which side is wrong. **The second
  case needs the line in `Goal` or `Constraints` that the requirement, correctly implemented, fails
  to reach; without one you have a finding and not a verdict.** (Why the silent-only reading was not
  enough, and why widening this definition alone reached nobody: `references/design-notes.md`.)

`FAIL` and `TASK_UPDATE_REQUIRED` are genuinely different: one goes back to the implementer, the
other goes back to the coordinator. **Returning `FAIL` where the spec was silent asks somebody to
fix code against a requirement that was never written down, and returning `PASS` where the
requirement points at the wrong thing records the task as finished at the last moment anybody could
have said otherwise.**

This file defines the skeleton, not the findings. How a finding is worded and how severe it is
belong to whoever performed the review.

---
name: workflow
description: Create and maintain the three files that carry a task from specification to accepted implementation - TASKS.md (the only formal spec), TASK-CHANGES.md (change proposals awaiting a decision), and REVIEW.md (a ledger of numbered review findings and the passes that raised them). Invoked as /claude-min-plugin:workflow <init | change | decide | review | trim>, and with no subcommand it lists those five and stops. Every entry carries a stable id, the files are appended to rather than overwritten, and a coordinator rules on one entry by naming its number. A one-word Rigor level in the spec sets the budgets that let a task end. Use when turning an approved plan into a spec, when a role finds the spec incomplete or contradictory, when recording a review, when ruling on a numbered proposal or finding, or when a ledger has grown past what is still live.
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
| `.workflow/REVIEW.md` | A ledger of review findings, and the passes that raised them | Whoever reviewed, the implementer in its own section, plus the coordinator's rulings |

**The coordinator is whoever owns the task** - normally the human, or the main session working
directly with them. Implementer and reviewer roles are never coordinators.

They live under `.workflow/` rather than at the repository root so they never collide with a
`TASKS.md` the project already had, and so a reviewer's write whitelist can be drawn as a path
prefix. All three belong in version control.

**The two ledgers are appended to, never overwritten.** `TASK-CHANGES.md` and `REVIEW.md` only ever
grow - a later pass adds to what is already there, the only in-place edit is recording a ruling on
an entry that already exists, and **no entry is ever deleted** - `trim` shortens entries and removes
none. **`TASKS.md` is the
exception and is meant to be**: it is the spec rather than a ledger, the coordinator owns it, and
`decide` folds accepted wording straight into it instead of appending a correction after the thing
it corrects.

Overwriting a ledger would make every ruling in it depend on somebody having committed the file
between passes. The coordinator can commit; neither agent can, and nothing in this workflow tells
anyone to - so a ledger that survives only when it happened to be committed does not survive.
`trim` does not weaken this - it makes entries shorter, never fewer, and it is the coordinator's to
run.

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
| `trim` | Cut the ledgers back to what is still live | The coordinator only |

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

Allocating from what is present is only safe because **no subcommand ever removes an entry** - not
even `trim`, which rewrites entries shorter and leaves every id where it is. Anything that deleted
the highest-numbered entries would hand the next one an id that already means something else, and
the ruling recorded against it would name two unrelated things.

### `init`

Write `.workflow/TASKS.md` from the plan approved in this session - the usual route is plan mode,
approved, then this. When a plan file path is given as a further argument, read that instead.

**Ask for the `Rigor` level once, as a single question, and never block on it.** Three options with
`low` selected. When there is no way to ask - a headless run, or a subagent with nobody to answer -
write `low` and say so. `low` is the tightest budget, so an unattended run cannot quietly grant
itself a large one; a task that turns out to need more gets its `Rigor` line raised by the
coordinator, which is an edit anyone can see. This is the only budgeting question this workflow
ever puts to a human - every number follows from the answer.

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
the reasoning that closed it. Nothing else in the entry is rewritten, and no entry is deleted by
this or any other subcommand, `trim` included.
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

**A pass takes the next number after the highest that appears anywhere in the file** - in the pass
log, or in any finding's `Raised:` line. Counting the entries in the log would be the obvious rule
and it breaks on an interrupted review, which is required to leave its findings behind and write no
pass entry: those findings already say `pass 3`, the log still ends at `Pass 2`, and the next
reviewer would call itself `Pass 3` as well. Two different reviews would then share a number, and a
finding would be attributed to a review it was never part of.

**Reopening.** A finding marked `FIXED` that you can still reproduce goes back to `Status: OPEN`,
with a line appended under its `Decision` naming this pass and what you saw. `WONTFIX` and
`DEFERRED` are the coordinator's calls - leave them exactly where they are however much you
disagree, and put the disagreement in your report instead.

**A review can end the task, and is meant to.** Apply these before writing the pass entry:

- A pass with nothing `Blocking` and at most two `Should fix` is the task's last pass. Write
  `Termination: budget met`, and **recommend a ruling for every finding it leaves `OPEN`** - naming
  the ids, and naming which ruling: `WONTFIX` for anything the level or `Out of scope` put outside
  scope, matching what `decide` calls the expected outcome there, and `DEFERRED` for what is real
  and worth doing but outside this budget. Cover the `Should fix` ones too, not only what sits below
  them: a task cannot be both over and carrying open findings, and those are the ones a later reader
  will assume somebody is still working on. Recommending is as far as this goes - setting a `Status`
  is `decide`, and `decide` is the coordinator's. A reviewer who rules on its own findings has
  closed its own review.
- When the pass before this one raised at least one finding, and this pass raised as many or more,
  write `Termination: DIMINISHING RETURNS` and say so on the report's second line, straight after
  the verdict. It is a signal to the human - narrow the scope or accept the work as it stands - not
  a verdict, and it does not turn `PASS` into `FAIL`. The floor matters: without it a clean pass
  following a clean pass satisfies "as many or more" at zero and escalates a review that found
  nothing. A first pass has nothing to compare against, so it never carries this either.
- When the passes the `Rigor` level allows, or an explicit `Review budget`, are spent, no further
  pass is written. A reviewer asked for one anyway records the refusal and the budget instead.
- **A pass that returns `FAIL` does not spend the budget.** The budget limits how many times the
  work is reviewed *afresh*, not how many times a named fix is confirmed - counting a `FAIL` would
  make `low`, which allows one pass, unable to finish any task that fails once: the only pass it
  permitted said `FAIL`, and a finished task needs a `PASS`. A pass that only re-checks what a
  previous `FAIL` named writes `Termination: confirming <F-nnn>` and reviews nothing else. Three
  consecutive `FAIL`s on one task is `DIMINISHING RETURNS` and goes back to the human.
- A finding against the test apparatus itself - a fixture, a mutant, a harness, a guard on another
  guard - takes **at most** the severity the `Rigor` table gives it, **unless you can name the
  user-visible failure it lets through**, in which case it takes the severity that failure deserves.
  *Could this test pass while the code is broken?* has a yes answer for every finite suite, so it
  cannot be the thing that decides whether reviewing ends - but a suite that never runs its
  assertions at all is not that question, it is a check that does not exist, and the cap is not a
  licence to ship one.
- A finding whose triggering situation is outside the level's scope, or is named under
  `Out of scope`, is `Consider`, and says which of the two put it there.

**When `REVIEW.md` is already there in a shape this skill does not describe** - written before these
conventions, or by hand - do not rewrite it and do not give its findings ids. Append the new ledger
below it, with one line saying where the old content ends and why what is above carries no ids. An
id is a promise that somebody verified the thing it names; putting one on a finding you have not
re-verified spends that promise on something you never saw.

### `trim`

Coordinator only. Shorten `TASK-CHANGES.md` and `REVIEW.md` without losing anything they record.
Runnable at any point - a ledger several times the size of the work it reviewed is unreadable long
before the task finishes, and where the repository root is a plugin it ships to every installer's
cache.

**`trim` never deletes an entry.** It rewrites each one shorter and that is all. Deleting was the
obvious design and it is wrong three ways at once: `review` has to be able to reopen a `FIXED`
finding under the id it already had, the pass log is the only record that an earlier task ever
passed (`TASKS.md` deliberately carries no status field), and ids are allocated from the highest
present, so removing the highest ones hands the next entry an id that already means something else.
Every one of those is a silent failure. Length is a readability problem; the entries are the record.

- **Condense every entry**, whatever its `Status`. Keep the id, the `Status`, the defect or proposal
  in one sentence, the `Raised:` line, and the ground the ruling stood on. Process narration, quoted
  output and superseded discussion go; a `Decision` ruled on more than once collapses to the ruling
  that stands, dated.
- **Condense pass entries the same way** - keep every one, cut each to its verdict, task, target,
  `Raised`, and `Termination`. The per-pass narrative under it is what grows without bound.
- **Never renumber, never delete, never merge two entries into one.** A `DEFERRED` finding that
  comes back has to come back as itself.

A ledger that is still too long after this is telling you the task was too big, not that `trim`
should delete more.

## `.workflow/TASKS.md`

```md
# Tasks

## Goal
One paragraph - what this work is for, in terms of the outcome rather than the implementation.

## Constraints
What must stay true. Compatibility, performance budgets, things that must not change.
Rigor: low | medium | high   <- one word; absent means low. It sets the budgets below.
Size budget: <optional override - lines across every file this task creates or grows, tests included>
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
| Size budget | 2x the lines the task replaces; 300 for new work | 3x; 500 | none - reported, not capped |
| Review budget | 1 pass | 2 | 3 |
| In scope | situations met in normal use, plus any silent loss | also rare situations that fail loudly | every reachable situation |
| Findings against the tests themselves | `Consider` | `Consider` | `Should fix` when the test guards a past defect |
| Proof required of a test | it was run and passed | it was seen to fail before it passed | the same |

"Normal use" has a test that needs nobody to answer it: **would a maintainer of this repository hit
the situation within a year of ordinary work?** If not, it is rare. Rare *and silent* - a file
skipped with no trace, a count that reads as clean - is in scope at every level, because silence is
the one failure nothing later catches. Rare *and loud* - the run stops and says why - is out of
scope at `low`. Cosmetic is out of scope everywhere. An explicit `Size budget`, `Review budget` or
`Out of scope` line always beats the level.

A budget the work then exceeds is reported as a number, never silently absorbed.

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
what each review actually did; its verdict never changes, and no entry is ever removed - `trim` only
shortens the narrative under one.

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

## Findings - implementer

### F-004
<Same fields. A code defect the implementer hit that is not a gap in the spec - a spec gap is a
TCR, not a finding.>

## Passes

### Pass 1 - 2026-08-25
Verdict: PASS | FAIL | TASK_UPDATE_REQUIRED
Task: T1
Target: <the diff, branch, commit range, or paths that were reviewed>
code-review: <the level it ran at and what it actually covered> | not run - <why>
Raised: F-001, F-002, F-003 | none
Required fixes: <the F-nnn that must be addressed before this can pass> | none
TASKS.md update needed: yes - <TCR ids> | no
Termination: budget met | DIMINISHING RETURNS | confirming <F-nnn> | continue - <what the next pass must look at>

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
is anchored to `file:line` with the concrete case that triggers it, and ids are unique across all
three sections, so `F-003` names one finding no matter which section it sits in.

Keeping the three finding sections apart is what makes the review auditable - `/code-review` is one
input to a pass rather than the pass itself, and the implementer's section holds defects found by
someone who was building rather than reviewing. A reader has to be able to tell which process
produced which finding. **When `/code-review` could not be run, that belongs in the pass entry's
`code-review` line, not in its findings section** - it is a fact about one pass, and a missing pass
that reads as "found nothing" is this step's one failure.

**The implementer's section is the only one the implementer may write to**, and only by appending a
finding, **creating the file with its headings when it does not exist yet** - which is the normal
case, since implementation usually runs before any review. Without it, a code defect found while
building has nowhere to go but a free-form report, and a report is read once and then gone.

The finding it appends carries `Status: OPEN` like any other. **`OPEN` is the absence of a ruling,
not a ruling** - writing it is how the entry becomes visible to `decide`, to `trim`, which sorts by
`Status`, and to the next implementer, which works only what is `OPEN`. A finding with no `Status`
at all is skipped by all three, which is the one outcome this section exists to prevent. Every other
value is a ruling and belongs to the coordinator, and so does every `Decision` line.

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

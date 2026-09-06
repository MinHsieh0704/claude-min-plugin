# Evaluation - 0.9.0-rc.2 workflow, developer and reviewer

Written 2026-09-06. This is not one of the three files the `workflow` skill defines and no
subcommand touches it. It records what a live trial of that skill measured, so the numbers survive
the session that produced them.

**The question it answers**: the 0.8.0-era run on `feature/update_language_check_rule` produced a
ledger several times the size of the work it reviewed. Do the rc.1 and rc.2 changes fix that?

**Short answer**: they fix *termination* and they do not fix *reviewing prose*. The budget is the
mechanism that does the work, and it is more effective than any convergence signal.

---

## 1. The baseline

`feature/update_language_check_rule`, run under the 0.8.0 workflow skill. Measured from its
committed `.workflow/`:

| | |
|---|---|
| Review passes | 7 |
| Findings | 78 |
| Change proposals | 22, **all 22 `ACCEPTED`** |
| Finding rulings | 77 `FIXED`, 1 `DEFERRED`, **0 `WONTFIX`** |
| Tasks | 8 - the spec grew from 3 to 8 mid-run |
| Ledger size | 6,370 lines against ~1,452 lines of actual change - **4.4:1** |

Findings raised per pass: **13, 10, 9, 9, 12, 10, 15**.

The last pass raised more than any other and returned `PASS`. That run did not end because it
converged; it ended because somebody stopped it.

**Why it could not end**: none of the terminating mechanisms existed in the skill version it ran
under. `Rigor`, `Review budget`, `Out of scope`, `DIMINISHING RETURNS` and `trim` are all absent
from that revision, and guideline 11 (root-cause grouping) had not been written. `WONTFIX` existed
as a value and was never used.

**Where the findings landed** - this is the half the budget does not address:

| Target | Findings |
|---|---|
| `skills/language-check/SKILL.md` | 31 |
| `tests/test-language-check-scan.sh` | 21 |
| `CLAUDE.md` | 8 |
| `.workflow/TASKS.md` | 7 |
| `README.md` | 3 |
| `references/language-convention.md` | 2 |
| `scripts/scan.sh` (the only executable code) | **6** |

**56% of the findings were against Markdown prose; 8% were against code.** The deliverable was
itself a specification document, and prose has no natural floor - "this could be clearer" is always
available. rc.2's test-apparatus severity cap reaches part of the 21 test-file findings (12 were
`Should fix` and would now be capped at `Consider`); nothing reaches the 31 against `SKILL.md`.

---

## 2. The counterfactual

Applying rc.2's budget to the same per-pass counts. The budget is the highest pass number allowed,
so the run stops after that pass:

| `Rigor` | Budget | Stops after | Findings | vs 78 |
|---|---|---|---|---|
| `low` (the default when the line is absent, which it was) | 2 | pass 2 | 23 | 29% |
| `medium` | 3 | pass 3 | 32 | 41% |
| `high` | 4 | pass 4 | 41 | 53% |

`DIMINISHING RETURNS` (two consecutive passes both raising findings, count not falling) would have
fired at passes **4, 5 and 7**.

**An alternative was measured and is worse.** Replacing the budget with "stop on the second
`DIMINISHING RETURNS`" ends the run after pass 5, at **53 findings** - more than twice `low`'s 23.
A convergence signal is not a substitute for a hard cap, because the counts do not converge.

---

## 3. The live trial

Two tasks (T1, T2) run through `init` -> `developer` -> `reviewer` -> `decide`, recorded in the
three ledgers beside this file.

| | Baseline | This trial |
|---|---|---|
| Passes | 7 | 3 |
| Findings | 78 | 8 |
| Ledger : change | 4.4 : 1 | ~1.2 : 1 |
| Rulings used | `FIXED`, `DEFERRED` | `FIXED`, `DEFERRED`, `WONTFIX` |

The ratio is not a like-for-like comparison - different task sizes, and this trial was stopped
deliberately rather than run to exhaustion. The pass count and the ruling spread are the meaningful
figures.

**Mechanisms that fired for the first time**

- **`DIMINISHING RETURNS`** - emitted on pass 2 (2 findings then 3, non-zero and not falling) and
  correctly *not* emitted on pass 3 (3 then 1, falling). The signal discriminates; it is not sticky.
- **`WONTFIX`** - F-004. Verified across the whole history of this repository that no ledger had
  ever carried `Status: WONTFIX` or `Status: REJECTED` (checked with positive controls on
  `Status: ACCEPTED` and `Status: FIXED`, which do return hits).
- **`trim`** - run 2026-09-06 on this trial's own ledgers: `REVIEW.md` 672 -> 302 lines,
  `TASK-CHANGES.md` 93 -> 74. Every id, every field, every `Decision` block and every
  `Proposed change` block preserved, verified by diffing the extracted structure rather than by
  reading.
- **The interruption rule** - a rate limit killed the pass-1 reviewer and its `/code-review` child
  mid-review. It had already appended F-001 and F-002 and had written **no pass entry and no
  verdict**, which is exactly what the skill requires. This was a real interruption, not a
  simulation.

**Still never exercised**: `Status: REJECTED`, and `init`'s `Rigor` question (it needs a live
foreground session; this trial set the level directly).

---

## 4. What the mechanisms do not address

- **Prose review has no floor.** The budget caps the number of passes, not the appetite of any one
  pass. Where the deliverable is documentation, the cap is doing all the work.
- **The budget is counted in passes, and a pass is not a unit of cost.** In this trial pass 1 was
  killed part-way by a rate limit, pass 2 took ~19 minutes, pass 3 took ~38 minutes and 104 tool
  calls. All three spent one unit.
- **Two open inconsistencies in the skill itself**, both hit during this trial and both recorded in
  `skills/workflow/references/design-notes.md`: whether the budget is per-file or per-task, and
  `Rigor` controlling both the budget and the scope rules.
- **A count written in prose has no check behind it.** `CLAUDE.md`'s Verification block went stale
  three times inside one task (F-002 added the line, F-003 and F-007 corrected its number). Each fix
  was correct; the repetition is evidence about the construct, not about the fixes.

---

## 5. The two agents

Judged against their transcripts under
`~/.claude/projects/<cwd-slug>/<session>/subagents/`, not against their own reports.

**`developer`** - boundaries held on every run. `.workflow/TASKS.md` was read and never written; no
`commit`, `add`, `stash`, `reset`, `checkout` or `push` appeared in any transcript (one `git stash`
match turned out to be `git stash list`, which is read-only); `REVIEW.md` received only appended
`Source: implementer` findings with no `Decision` line and no pass entry. Its strongest behaviour
was refusing to work around a broken acceptance criterion - TCR-002 caught a coordinator-authored
`grep -n '[^\x00-\x7F]'` that matches all 35 lines of a pure-ASCII JSON file, i.e. a criterion that
could not come back negative. Its weakness is that it does not see past its own verification: it
mutation-tested its suite seven ways and never asked whether the suite could pass while the subject
was broken, which is F-001.

**`reviewer`** - asked exactly that question, and answered it by demonstration rather than
assertion. It also confirmed `/code-review`'s effort level from the run's own `forked-skill.json`
rather than from its own call arguments, marked a rate-limited `/code-review` as *absent, not
clean*, dropped the majority of `/code-review`'s findings with reasons that survived checking
(including one where recording the finding "would penalise the guideline being followed"), and left
a `WONTFIX` it disagreed with untouched while putting the disagreement in its report. Its one
judgement failure was in pass 1: it diagnosed that the spec pointed the requirement at the wrong
object and still returned `PASS` with `TASKS.md update needed: no` - because the only verdict that
returns work to the coordinator required the spec to be *silent*. That gap is now closed
(`73bb6e9`).

**The division of labour is real rather than ceremonial.** The implementer verifies that the test
passes; only somebody who did not write it asks whether it would fail. If one of the two had to go,
the reviewer is the one that pays for itself.

---

## 6. Open at the time of writing

- `F-001` and `F-008`, both `DEFERRED`, in `REVIEW.md`.
- The two design-notes inconsistencies above.
- Extracting the shared test harness duplicated between
  `skills/commit/tests/test-commit-msg-hook.sh` and `hooks-handlers/tests/test-session-start.sh`.

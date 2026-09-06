# Review

Trimmed 2026-09-06. Every entry and every field is still here; only prose was shortened.

## Findings

### F-001
Status: DEFERRED
Severity: Consider
Source: manual review
Task: T1
Where: hooks-handlers/tests/test-session-start.sh:76
Raised: pass 1, 2026-09-05

The suite compares the handler's *file text* against the source and separately asserts only that
the emitted `additionalContext` is non-empty, so nothing ties the list that was compared to the
list a session receives. Demonstrated: a handler emitting
`"additionalContext": "guidelines temporarily disabled"` with the summary kept below as a comment
passed all nine cases.

Decision:

- 2026-09-05 DEFERRED - real, and in scope by the silence rule rather than outside it. Deferred on
  cost, not impact: the fix feeds the comparison from the parsed `additionalContext` instead of the
  file, which changes what T1's Requirement says it reads from, so it needs a spec change and a
  round the budget did not have. Carry it as the opening requirement of whatever picks this up.

### F-002
Status: FIXED
Severity: Consider
Source: manual review
Task: T1
Where: hooks-handlers/tests/test-session-start.sh:1
Raised: pass 1, 2026-09-05

Nothing in the repository ran the new suite, so the Goal's "gets a red test" depended on somebody
remembering the file exists. `CLAUDE.md`'s Verification block, the only written verification
routine, listed three commands and not this one.

Decision:

- 2026-09-05 FIXED - impact decided it: a suite absent from that block is one nobody runs, and the
  Goal's outcome depends on it running. One line added after the commit-msg suite, by the
  coordinator, whose file that block is.

### F-003
Status: FIXED
Severity: Should fix
Source: implementer
Task: T2
Where: CLAUDE.md:15 and CLAUDE.md:48
Raised: implementer, 2026-09-05

T2 falsified two statements. Line 15 told a maintainer to regenerate the summary by hand and said in
bold that taglines were uncovered - after T2 the first is a generated line and the second is what
the suite now covers. Line 48 read `expect 9/9` against a suite printing 12. `Should fix` because
line 15 is the paragraph anybody editing the guidelines reads first and it misdirects them into
hand-editing generated output; not `Blocking` because both failures are loud.

Decision:

- 2026-09-05 FIXED - impact decided it. Line 15 rewritten to say the tagline lives beside its
  heading, that the generated line is never hand-edited, and that only a tagline going stale against
  its own section stays uncovered; line 48 set to `expect 12/12`. By the coordinator, whose file it
  is.

### F-004
Status: WONTFIX
Severity: Consider
Source: /code-review
Task: T2
Where: hooks-handlers/tests/test-session-start.sh:183 and :190
Raised: pass 2, 2026-09-05

`mutate_skill_tagline` and `mutate_skill_escapes` anchor on the first `^<!-- summary: ` line
anywhere rather than the first one following a numbered heading, so a summary comment placed
elsewhere in `SKILL.md` turns cases red with nothing broken - reproduced, `10 passed, 2 failed`.
The file's own header states the opposite intent. `Consider` as a finding against the test
apparatus that lets no user-visible failure through.

Decision:

- 2026-09-05 WONTFIX - ruled on the probability of the trigger. That comment exists for exactly one
  mechanism, so an unattached one has no reason to be written; when it does happen the suite goes
  red and names the case, so it costs no data. Reopen it the moment somebody has a reason to write
  one anywhere but under a heading - the fix is small and this ruling is about likelihood only.

### F-005
Status: FIXED
Severity: Consider
Source: /code-review
Task: T2
Where: hooks-handlers/generate-session-start.py:92-93
Raised: pass 2, 2026-09-05

Given one positional argument the generator read it as the `SKILL.md` and silently defaulted the
handler to the repository's own, so a run meant to try a scratch source rewrote the committed
handler from it. Reproduced on a copy.

Decision:

- 2026-09-05 FIXED - ruled on cost, and paid in the same round as F-006 because both are the
  generator trusting what it is handed. `main()` now takes two positional paths or none; verified
  by the coordinator, one path exits 1 with `usage: ... both paths or neither`. The root-cause
  grouping held as a work order but not as one edit - two guards was the smallest honest fix.

### F-006
Status: FIXED
Severity: Consider
Source: /code-review
Task: T2
Where: hooks-handlers/generate-session-start.py:29
Raised: pass 2, 2026-09-05

The summary pattern accepted an empty tagline, so a guideline could reach every session as a
number, a title and a dangling separator with nothing after it. One space separated a loud failure
from a silent one: `<!-- summary: -->` did not match and failed loudly, `<!-- summary:  -->` matched
with an empty group, exited 0, and emitted the blank. Both verified against copies.

Decision:

- 2026-09-05 FIXED - ruled on impact, and against the finding's own `Consider` reasoning: rare *and
  silent* is in scope at every level, and that decided it rather than how recoverable the loss was.
  Verified by the coordinator on a copy - the two-space form now exits 1 naming the heading, and
  `sha256sum -c` confirms the failed run wrote nothing, so there is no partial write.

### F-007
Status: FIXED
Severity: Consider
Source: implementer
Task: T2
Where: CLAUDE.md:48
Raised: implementer, 2026-09-05

Closing F-005 and F-006 added two cases, so the Verification block again named a count the suite no
longer printed - `expect 12/12` against `Results: 14 passed`. `Consider`: this is the loud half of
F-003 rather than the misdirecting half.

Decision:

- 2026-09-05 FIXED - ruled on cost: one number in a file the coordinator owns, now `expect 14/14`.
  Third time that block has gone stale in one task, which is worth noticing rather than repeating -
  a count in prose has no check behind it, and the next change to the suite will falsify it again.

### F-008
Status: DEFERRED
Severity: Should fix
Source: /code-review
Task: T2
Where: hooks-handlers/generate-session-start.py:86
Raised: pass 3, 2026-09-05

`rewrite()` replaces the whole matched line, discarding anything that followed the value. Add a
sibling key after `additionalContext`, with the comma JSON then requires, and the generator drops
that comma while printing `regenerated` and exiting 0 - leaving a SessionStart hook whose stdout
raises `Expecting ',' delimiter`. It is the generator's only write-and-report-success path; it
fails loudly on every other bad input. `Should fix` rather than `Blocking` because the tree is
green and the trigger is a future edit; in scope at `medium` as rare-but-loud.

Decision:

- 2026-09-05 DEFERRED - ruled on cost against a spent budget, not on impact and not because the
  finding is wrong. Reproduced by the coordinator. What makes deferring safe rather than convenient:
  the corruption is silent only at generation time - the suite reports `10 passed, 4 failed` on the
  next run, and `CLAUDE.md`'s Verification block tells people to run it. Carry it alongside F-001.

## Passes

### Pass 1 - 2026-09-05
Verdict: PASS
Task: T1
Target: the untracked `hooks-handlers/tests/test-session-start.sh` (265 lines), the whole of the
work under review; `git diff` and `git diff --staged` both empty. `.workflow/` read as spec, not
reviewed as code.
code-review: invoked as `/code-review medium hooks-handlers/tests/test-session-start.sh`; level
confirmed from its own `forked-skill.json` (`"effort":"medium"`). Terminated by a rate limit before
returning findings, so this pass carries no `/code-review` input - treat that coverage as absent,
not clean. Every finding above is `Source: manual review`.
Raised: F-001, F-002
Required fixes: none
TASKS.md update needed: no

#### TASKS.md compliance
All six criteria MET: the suite prints `Results: 9 passed, 0 failed` in the commit-msg suite's
shape; cases 2-4 exercise the three heading mutations from within the suite; cases 7-9 assert on
distinct stderr strings for invalid JSON, wrong `hookEventName` and empty `additionalContext`;
`git status --porcelain` is identical before and after every run; all 35 non-ASCII lines are
comments; and the handler still emits one valid SessionStart document, asserted by a real parser.

#### Verification
`bash hooks-handlers/tests/test-session-start.sh` -> 9/9, exit 0, twice, tree unchanged.
`claude plugin validate . --strict` -> `Validation passed`. Mutation-tested outside the repository:
a renamed handler title, a renumbered `SKILL.md` heading (named in the Requirement but not shipped
as a mutator, so checked by hand) and a wholly removed summary each turn case 1 red naming both
sides; a handler emitting a stub context with the summary kept below as a comment stays 9/9, which
is F-001. Not run: the commit-msg suite - it `chmod +x`es a tracked file and no tracked file
changed. Discipline: guidelines 1 and 11 evidenced by TCR-001 and TCR-002 changing the spec rather
than working around an uncheckable criterion, 3 by the handler and `SKILL.md` being untouched, 6 by
Python admitted through a TCR, 9 by the missing-interpreter exit and the both-lists-empty guard.
Guideline 10 leaves no trace in a diff and was not judged.

### Pass 2 - 2026-09-05
Verdict: PASS
Task: T2
Target: the uncommitted work on `worktree-wf-rc2-trial` - `git diff` over `CLAUDE.md`,
`hooks-handlers/session-start.sh`, `hooks-handlers/tests/test-session-start.sh` and
`skills/coding-guidelines/SKILL.md`, plus the untracked `hooks-handlers/generate-session-start.py`
read directly. `.workflow/` read as spec and ledger.
code-review: `/code-review medium` over those five paths; level confirmed from its own fork record
rather than inherited. It resolved its own target and landed on the same diff. 23 tool calls, all
reads, no `--fix`. Five findings: three recorded above after independent reproduction, two dropped
for the reasons under Verification.
Raised: F-004, F-005, F-006
Required fixes: none
TASKS.md update needed: no

#### TASKS.md compliance
All seven criteria MET. The handler emits the same 2359 bytes, sha256 `60998b93...78d`, and `cmp`
against `git show HEAD:hooks-handlers/session-start.sh` confirms the taglines moved verbatim. The
generator round-trips (`already up to date`, no write) and its docstring names the command. The
suite is 12/12 with its drift half now `cp` + generator + `cmp -s`. Case 5 covers a tagline changed
without regenerating; cases 2, 3, 4, 9, 10, 11 still cover the heading mutations and the three JSON
failures - the removed-heading assertion moved from `only in the summary` to `^< 1\. `, a
re-anchoring onto the new message rather than a loosening. Case 12 covers `"` and `\` escaping.
"Checked in" is true only in the sense the rest of this work is: nothing on this branch is
committed yet.

#### Verification
Suite 12/12 twice, byte-identical, tree unchanged. `claude plugin validate . --strict` passes;
`scan_output_symbols.py` on the generator reports 0; the frontmatter colon grep returns nothing.
Mutation-tested outside the repository: naive quoting in place of `json.dumps` turns case 12 red; a
generator that skips an unsummarised heading turns case 6 red; a tagline edited without
regenerating turns case 1 red and goes green after regenerating, with the new text reaching stdout,
which is the Goal's round trip. Three further mutants are the findings above (F-004, F-005, F-006).
On F-001: T2 narrows it - its pass-1 reproduction now turns the suite red, case 12 being the first
assertion tying a string in `SKILL.md` to the handler's stdout - but a handler post-processing its
own heredoc still passes 12/12. Same defect, narrower trigger, recorded here rather than as a new
id. Two `/code-review` findings dropped after checking: `CLAUDE.md:17` is not stale (the
"nothing to detect its drift" clause attaches to the `README.md` Agents table, and a generated
summary is still a derived copy), and the `split("\n")` / `splitlines()` mismatch is real only on a
CRLF handler, which `.gitattributes` prevents and which carries exactly the one-line
not-handled note guideline 2's collision rule with 9 asks for - recording it would penalise the
guideline being followed. Not run: the commit-msg suite, for pass 1's reason; `claude --plugin-dir .`
and the preload probes, which need a live session and no agent or manifest changed. Discipline:
guideline 2 by the CRLF non-handling being one comment line, 3 by each file's change being confined
to what the task named, 6 by no tool beyond TCR-001's admission, 8 by the generator's docstring
carrying four decisions a reader would otherwise guess, 9 by three loud exits one of which is
mutation-tested.

### Pass 3 - 2026-09-05
Verdict: PASS
Task: T2
Target: the same five paths as pass 2 - `git diff` over four tracked files plus the untracked
generator read directly. `.workflow/` read as spec and ledger.
code-review: run twice at `medium`, both over the same five paths and both resolving to this same
diff. The first stalled 23 minutes and was retried, then returned after the retry had answered, so
this pass carries both reports. Levels confirmed from the runs' own records - the first wrote
`"effort":"medium"`; the retry wrote no `forked-skill.json`, so its level was confirmed from its
opening prompt carrying the identical effort profile line. Neither used `--fix`, `--comment`,
`--post` or `ultra`; 10 and 19 tool calls, all reads. Eight findings between them: one recorded
above after independent reproduction, seven dropped.
Raised: F-008
Required fixes: none
TASKS.md update needed: no

#### TASKS.md compliance
All seven criteria MET. The handler still emits 2359 bytes, sha256 `60998b93...78d`, `cmp`-clean
against `HEAD`'s stdout. The generator round-trips, writes nothing when current, and is
cwd-independent. The suite is 14/14, repeatedly and identically. Case 5 covers a tagline changed
without regenerating, end to end on a copy; cases 2, 3, 4, 9, 10, 11 still cover the heading
mutations and the three JSON failures; case 13's needle half is independently effective - a
generator emitting valid JSON with an unescaped backslash turns it red.

#### Verification
F-005, F-006 and F-007 each confirmed still fixed, by reproducing their original triggers rather
than by reading: one positional argument exits 1 and leaves the handler's sha unchanged; the
two-space summary exits 1 and `cmp` shows nothing written, and `.strip()` also catches a tab-only
tagline; `CLAUDE.md:48` reads `expect 14/14` against a green `14 passed`. No case came back weaker,
established by mutation rather than by reading: each new case is independently effective, the four
`check_output` assertions and the three JSON invocations are byte-identical to `HEAD`, and
replacing `check_drift`'s content `diff` with `diff -q` turns cases 2-5 red, so all four assert on
diff content rather than on a non-zero exit alone. Seven `/code-review` findings dropped after
checking; three are worth naming because they look like defects and are not - `unfold()`'s GNU-sed
dependency is real but pre-existing and *narrowed* by T2 (neutralising it at `HEAD` turns two cases
red including the positive one); CRLF handler corruption reproduces but `git check-attr` confirms
`text: set` / `eol: lf` normalises on add as well as checkout, so mixed endings cannot escape the
working tree; and `CLAUDE.md:17` is wrong for the same reason pass 2 gave. Pre-existing, one line
each: `skills/coding-guidelines/SKILL.md:3`'s frontmatter `description` enumerates ten guidelines
and omits guideline 11, and the interpreter probe admits Python 2 unchanged from `HEAD`. F-004
stays `WONTFIX` and F-001 stays `DEFERRED`, both untouched, with one disagreement on the record:
F-004's blast radius grew, because the new blank-tagline mutator anchors on the same first line, so
an unattached comment now turns three cases red rather than two. F-001's narrowed reproduction
still holds - a handler post-processing its own heredoc corrupts every session and the suite still
reports 14/14. The reviewed tree is byte-identical to how it was found, `sha256sum -c` clean on all
five files.

#### Last-pass recommendations
One finding was `OPEN` at the close of this pass and needed a ruling: **F-008 -> `DEFERRED`**, in
scope at this level rather than outside it, with the fix and a covering case being an
implementation round this budget no longer has. Everything else was already ruled - F-001
`DEFERRED`, F-002, F-003, F-005, F-006 and F-007 `FIXED`, F-004 `WONTFIX` - and none is recommended
for a change.

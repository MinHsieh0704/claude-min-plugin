# Task changes

Trimmed 2026-09-06. Every entry and every field is still here; `Proposed change` blocks are
untouched because they are wording somebody pastes into `TASKS.md`, not prose.

## TCR-001
Status: ACCEPTED
Task: T1
Source: implementer
Created: 2026-09-05

### Reason
`Constraints` said the check must run with "no new runtime dependency" *and* with "the tools the
existing suite already uses", and the two clauses disagree about Python: `CLAUDE.md`'s own
Verification block already requires it, while the existing suite uses only bash, grep, sed, printf
and mktemp. `jq` is absent on this host, so Python is the only real JSON parser available, and
nothing in `TASKS.md` settled which clause governs. It decides real code - without a parser the
three JSON assertions become text matching, which cannot see an unescaped quote inside the
`additionalContext` string and would report clean on documents that are not.

### Proposed change
Replace the first sentence of `Constraints` with:

> The check must run from the repository with no network access. Bash and the tools the existing
> suite already uses (grep, sed, printf, mktemp, awk) are the baseline; a Python interpreter may
> also be used, since `CLAUDE.md` already requires one to verify this repository. Any tool that is
> not already required somewhere in this repository counts as a new dependency and is not
> available.

### Impact
Confined to `check_output` and the interpreter probe above it if rejected; the drift half of the
suite uses no Python either way. The probe checks the interpreter's *output* rather than its exit
status, because on this Windows host `python3` resolves to the Microsoft Store stub, which prints
nothing and exits 49.

### Decision

- 2026-09-05 ACCEPTED - Python is already required to verify this repository, so it is not a new
  dependency, and the proposed wording gives "new dependency" a definition the original sentence
  lacked. Folded into `Constraints`.

## TCR-002
Status: ACCEPTED
Task: T1
Source: implementer
Created: 2026-09-05

### Reason
T1's fifth acceptance criterion named `git ls-files '*.sh' | xargs grep -n '[^\x00-\x7F]'`, which
is not a check for two independent reasons. GNU grep does not expand `\xNN` in a basic or extended
regular expression, so the bracket expression reads as "not one of `\ x 0 - 7 F`" and matches
almost every line of ordinary English - 20 of the 23 lines of an already-compliant
`hooks-handlers/session-start.sh`. And the criterion's own next sentence requires the file's
comments to be Traditional Chinese, which a whole-file non-ASCII scan cannot coexist with; the
`language-check` convention scopes the ASCII rule to runtime output, not to the file.

### Proposed change
Replace that acceptance criterion with:

> - Every non-ASCII character in the new file sits on a comment line: its runtime output - every
>   `echo`, `printf` and embedded interpreter message - is plain ASCII English, and its comments are
>   Traditional Chinese, matching the handler it tests. Checked per `skills/language-check/SKILL.md`
>   rather than by a whole-file grep, which cannot hold alongside the Traditional Chinese comment
>   requirement.

### Impact
Wording only. `hooks-handlers/tests/test-session-start.sh` already satisfies the proposed
criterion - every non-ASCII line in it is a comment line.

### Decision

- 2026-09-05 ACCEPTED - verified: the regex matches all 35 lines of the pure-ASCII
  `.claude-plugin/plugin.json`, so the criterion could not come back negative. Folded into T1's
  acceptance criteria.

---
name: language-check
description: Audit which parts of a repo are written in Traditional Chinese and which in English, and flag violations of the reader-based split — zh-Hant for code comments and human-facing docs, English and plain ASCII for all runtime output (stdout, stderr, thrown errors), skill and subagent-definition files, and manifests. Use when asked which parts of a project are Chinese vs English, when auditing language consistency, when a symbol or a localised label reaches a console and breaks its encoding, or before adding a comment, log line, or error message to a repo that follows this convention.
---

# Language check

Audit a repo's use of Traditional Chinese versus English, and report any text sitting on the
wrong side of the line. This is an analysis skill: it reads and reports, and only edits files
when explicitly asked to fix what it found.

## The rule

One question decides the language of every piece of text — **who reads it?** Never the file
extension, never whether it "looks like documentation".

**Traditional Chinese (zh-Hant)** — read only by the repo's own human maintainers:

- Code comments and docstrings, in every language.
- Human-facing prose that stays in the repo: `README.md`, design/rationale docs under a
  `references/` directory, ADRs.

**English** — leaves the repo, or is consumed by a machine:

- **All runtime output.** Anything printed to stdout, written to stderr, thrown as an error,
  or shown in a UI. An error message *feels* like it is for a human, but it is emitted by code
  and lands in logs and CI output.
- **Runtime output must be plain ASCII**, not merely free of CJK. A symbol — `⚠`, `→`, `✓`, an
  em dash, an emoji — is a character the receiving console may be unable to encode: on a
  non-UTF-8 code page Python's stdout raises `UnicodeEncodeError` and kills the run, while
  stderr silently degrades it to `⚠`. Surviving one code page is luck: `→` lives in cp950
  and dies in cp437. Symbols belong in the UI a repo renders, never in the stream it prints.
- **CJK also reaches output through interpolation.** `print(f'the "{label}" column is empty')`
  has no CJK on the line but prints Chinese whenever `label` binds to a Chinese display name.
  No scan sees this; step 6 checks it by hand. The fix is usually not to translate the
  constant (it is often a UI label and a dict key at once) but to add a parallel English table
  for the console side, guarded against drift at import time:

  ```python
  PERIOD_EN = {"<label-1>": "1D", "<label-2>": "1W"}
  if PERIOD_EN.keys() != {label for label, _ in PERIODS}:
      raise RuntimeError("PERIOD_EN must name exactly the labels in PERIODS")
  ```

- Files a machine reads: `SKILL.md`, subagent definitions (`agents/<name>.md`), `CLAUDE.md`,
  `AGENTS.md`, manifests (`plugin.json`, `package.json`), hook configuration, and any string a
  hook injects into a model's context.
- Anything distributed: published package metadata, and commit messages.
- Identifiers — function and variable names, CLI flags, config keys, file paths.

## Steps

1. Enumerate what is in scope: `git ls-files`. Audit tracked files only. Run everything below
   under a UTF-8 locale (`export LC_ALL=C.UTF-8` when `LANG` is unset): otherwise `grep -P`
   rejects the CJK ranges in steps 2 and 7, and step 7's loop prints an empty table instead of
   failing.

2. Split the files into "contains CJK" and "pure English":

   ```bash
   grep -rlP '[\x{4e00}-\x{9fff}\x{3000}-\x{303f}\x{ff00}-\x{ffef}]' $(git ls-files)
   ```

   (CJK ideographs, CJK punctuation, fullwidth forms. U+2014 em dash is deliberately left out
   here — English prose uses it.) **Any machine-read file from the rule's English list in the
   "contains CJK" set is a violation** — a `SKILL.md`, `CLAUDE.md`, or manifest with Chinese in it.

3. Build the scan set — every tracked text file except Markdown, which step 2 already covered:

   ```bash
   TEXT=$(for f in $(git ls-files); do grep -qI . "$f" 2>/dev/null && echo "$f"; done | grep -v '\.md$')
   ```

   Select by "is text", never by extension: an extension list misses extensionless git hooks
   and every language nobody listed.

4. **One net: every non-ASCII character on a line that is not a line-start comment.**

   ```bash
   echo "$TEXT" | xargs grep -nP '[^\x00-\x7F]' | grep -vP '^[^:]*:\d+:\s*(#|//)'
   ```

   Any non-ASCII character that reaches output sits on such a line — whatever the output verb,
   whether the statement spans lines, whether it is a heredoc. So this net is complete for
   literal text, and every line it returns is a **candidate, not a violation**. Read each one
   in context and put it in exactly one bucket:

   - **docstring** (a triple-quoted block that starts its own line)
   - **trailing comment** (code, then `#` or `//`, then zh-Hant)
   - **UI string** (rendered by the repo's own UI, not printed to a console)
   - **output** — stdout, stderr, an exception message, a hook's JSON payload, a manifest field
     a terminal displays. **Each of these is a violation.**

   Docstrings and triple-quoted templates look identical; only the position separates them (a
   docstring starts its own line, a template is assigned or passed). Filing a template under
   "docstring" hides exactly the strings the audit exists to find. Report the four counts and
   check they sum to the candidate count, with zero unclassified.

   One known gap: a non-ASCII line inside an output block that itself starts with `#` or `//`
   (a heredoc printing a `#` heading) is dropped by the filter. When a heredoc or template
   emits such lines, read it whole.

5. **Python cross-check:** `scripts/scan_output_symbols.py` in this skill's directory walks the
   AST and lists every non-ASCII character in a string literal under `print()`, `raise`, or
   `sys.exit()`:

   ```bash
   SCAN="${CLAUDE_PLUGIN_ROOT}/skills/language-check/scripts/scan_output_symbols.py"
   git ls-files '*.py' | xargs python "$SCAN"
   ```

   Use `python3` only where `python` is absent; on Windows `python3` is usually a Microsoft
   Store stub that prints nothing and exits 49. It exits 0 when clean, 1 on findings, 2 when a
   file cannot be parsed. Every hit it reports must also be in step 4's "output" bucket — a
   hit missing there means a candidate was misclassified. If it cannot run, say step 5 was not
   run; never replace it with a hand read and report that as its result.

6. **Interpolation, by hand.** For each output statement that interpolates a value, follow the
   name to where it is defined. A repo-defined constant carrying CJK or symbols is a violation
   even though steps 4 and 5 are clean. A value from user data (a filename, a record the user
   typed) must be echoed exactly as given — translating it is a bug, not compliance.

7. Report per-file counts as `CJK lines / total lines`:

   ```bash
   for f in $(git ls-files); do
     n=$(grep -cP '[\x{4e00}-\x{9fff}]' "$f") || true
     [ "$n" -gt 0 ] && printf '%-56s %4s / %4s\n' "$f" "$n" "$(wc -l < "$f")"
   done
   ```

8. Summarise in this order: the split (how many files each way), the per-file table, then the
   observed language of **code comments**, **stdout/print messages**, and **error/exception
   messages**. Close with the violations from steps 2, 4, 5 and 6, console and UI counted
   separately, plus step 4's bucket counts. A clean audit reports zeros *and* the bucket
   arithmetic that backs them, never the word "clean" on its own.

## Rules

- **Report, don't rewrite.** Only edit when asked to fix what the audit found.
- **A count is not a conclusion.** `grep -c` counts lines, not words; say what you actually saw.
- **A mixed line is not automatically wrong.** A zh-Hant comment quoting `git rev-parse
  --path-format=absolute` is correct — identifiers, commands, and paths keep their original
  language inside Chinese prose. Flag mixed *output*, not mixed prose.
- **Write counter-examples with placeholders.** A literal `echo "<zh-Hant>"` in a document is
  indistinguishable from a real violation.
- When a repo genuinely disagrees with this convention — English-only, or deliberately
  localised logs — describe what it does instead of forcing the rule onto it. That licence
  covers the language of the surface it renders, not the stream it prints: a symbol the
  console's code page cannot encode is a defect whatever the language policy.

The reasoning behind each side of the split and the cases that look like contradictions
(`README.md` in zh-Hant next to `CLAUDE.md` in English) are in
`references/language-convention.md` in this skill's own directory.

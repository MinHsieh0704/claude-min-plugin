---
name: language-check
description: Audit which parts of a repo are written in Traditional Chinese and which in English, and flag violations of the reader-based split — zh-Hant for code comments and human-facing docs, English for all runtime output (stdout, stderr, thrown errors), skill files, and manifests. Use when asked which parts of a project are Chinese vs English, when auditing language consistency, or before adding a comment, log line, or error message to a repo that follows this convention.
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
  or shown in a UI. This is the rule people break most often, because an error message *feels*
  like it is for a human — but it is emitted by code, lands in logs and CI output, and is read
  by whoever is on call, not only by the person who wrote it.
- Files a machine reads: `SKILL.md` frontmatter and body, `CLAUDE.md`, `AGENTS.md`, manifests
  (`plugin.json`, `package.json`), hook configuration, and any string a hook injects into a
  model's context.
- Anything distributed: published package metadata, and commit messages.
- Identifiers, of course — function and variable names, CLI flags, config keys, file paths.

The sharpest consequence, and the one worth checking first:

> **No CJK character may appear inside a string literal that becomes output.**
> In a healthy repo, every CJK character in an executable file sits in a comment or a docstring.

## Steps

1. Enumerate what is in scope: `git ls-files`. Audit tracked files only — build output and
   vendored dependencies are somebody else's language decision.

2. Split the files into "contains CJK" and "pure English":

   ```bash
   grep -rlP '[\x{4e00}-\x{9fff}\x{3000}-\x{303f}\x{ff00}-\x{ffef}]' $(git ls-files)
   ```

   The three ranges are CJK ideographs (U+4E00–U+9FFF), CJK punctuation (U+3000–U+303F: corner
   brackets, ideographic comma), and fullwidth forms (U+FF00–U+FFEF: fullwidth solidus, colon).
   **U+2014 em dash is deliberately not in the list** — English prose uses it too, and including
   it would flag every English line that has one.

3. Build the scan set: **every tracked file that is not binary.** No extension list, no language
   list, nothing to keep up to date.

   ```bash
   TEXT=$(for f in $(git ls-files); do grep -qI . "$f" 2>/dev/null && echo "$f"; done)
   ```

   `grep -qI .` succeeds only on files grep considers text, which is what drops images, PDFs and
   compiled artifacts. Selecting by extension instead (`*.sh`, `*.py`, …) fails in both
   directions and was tried first: it misses extensionless executables — a repo's git hooks are
   exactly that, and hook scripts are where error messages concentrate — and it silently misses
   every language nobody thought to list, `.ps1`, `.go`, `.tsx`, `.bat`. A scan that reports
   "clean" without having opened the repo's most error-message-dense file is worse than no scan.
   Casting the net over all text files removes that whole class of failure, and step 4's pattern
   is what keeps the precision.

4. **Run the violation scan first — it is the mechanical one: a hit is a violation, no judgment
   needed.** Match an output verb followed, on the same line, by CJK inside an ASCII-quoted
   string:

   ```bash
   VERB='(echo|printf|print|puts|sys\.exit|console\.(log|warn|error)|throw new|raise |Write-(Error|Host|Warning|Output)|fmt\.Print[a-z]*)'
   GAP='([^"'"'"']|"[^"]*"|'"'"'[^'"'"']*'"'"'){0,60}'
   echo "$TEXT" | xargs grep -nP "${VERB}${GAP}[\"'][^\"']{0,120}[\x{4e00}-\x{9fff}]"
   ```

   **Requiring the quoted string is what makes scanning everything viable.** Matching the verb
   alone flags any zh-Hant sentence that merely mentions `echo` or `print()` — which is precisely
   what a document about output conventions is full of, so the noise grows as the docs improve.
   Demanding that the CJK sit inside a quote after the verb removes that entire class: a comment
   reading `# <zh-Hant note that mentions print()>` no longer matches, while `echo "<zh-Hant>"`,
   `Write-Error "<zh-Hant>"`, `fmt.Println("<zh-Hant>")` and `raise ValueError("<zh-Hant>")` all
   do. (Those examples carry placeholders rather than literal CJK for the same reason the rule
   exists — this file is English, and a literal example would trip the scan it documents.)

   **`GAP` is doing real work; do not flatten it to `.{0,60}`.** It allows the span between the
   verb and the opening quote to hold either non-quote characters or *complete* quoted groups.
   A plain `.{0,60}` lets the regex walk past a finished string and treat its closing quote as an
   opening one, so a doc line like ``  `echo "<message>"`, followed by zh-Hant prose  `` matches
   and reports as a violation. Restricting the gap to non-quote characters instead swings too far
   the other way and misses `printf '%s\n' "<zh-Hant>"`, where a legitimate format-string argument
   sits between the verb and the message. Measured on a 15-case fixture set plus this repo: the
   alternation catches all 15 with zero false positives; `.{0,60}` costs a false positive and the
   no-quote form costs a miss.

5. Then the wider net, for output the verb list missed — a message assigned to a variable first,
   a heredoc, a UI label. Find CJK inside any ASCII-quoted string:

   ```bash
   echo "$TEXT" | xargs grep -nP "[\"'][^\"']{0,120}[\x{4e00}-\x{9fff}]" | grep -vP '^[^:]*:\d+:\s*#'
   ```

   The trailing filter drops line-start comments; `xargs` makes each output line
   `file:number:content`, which is why the anchor allows for the filename before the line number.
   **These are candidates, not violations** — the filter only recognises comments that start at
   the beginning of a line, so trailing comments (`some_call()  # <zh-Hant note>`), Python
   docstrings, and `//` or `/* */` comments all survive it and are perfectly legal, as is prose
   in a zh-Hant document that happens to quote something. Read each one and classify it by hand;
   never report the raw count as a violation count.

6. Report per-file counts as `CJK lines / total lines`, so the numbers say where the Chinese is
   concentrated rather than just which files have some:

   ```bash
   for f in $(git ls-files); do
     n=$(grep -cP '[\x{4e00}-\x{9fff}]' "$f") || true
     [ "$n" -gt 0 ] && printf '%-56s %4s / %4s\n' "$f" "$n" "$(wc -l < "$f")"
   done
   ```

7. Summarise in this order: the split (how many files each way), the per-file table, then the
   three categories the rule cares about most — **code comments**, **stdout/print messages**, and
   **error/exception messages** — each stated as its actual observed language. Close with any
   violations from step 4, or state plainly that there are none.

## Rules

- **Report, don't rewrite.** Translating a comment or an error message changes what a future
  reader sees; that is the maintainer's call. Only edit when asked to fix what the audit found.
- **A count is not a conclusion.** `grep -c` counts lines containing CJK, not Chinese words, and
  a line with one Chinese character in an otherwise-English sentence counts the same as a full
  Chinese paragraph. Say which one you actually saw.
- **Never claim "no exceptions" without having looked.** The step-4 filter leaves legal lines
  behind by design; a clean audit means each of those was read and classified, not that the
  grep came back empty.
- **A mixed line is not automatically wrong.** A zh-Hant comment quoting `git rev-parse
  --path-format=absolute` is correct — identifiers, commands, and paths keep their original
  language inside Chinese prose. Flag mixed *output*, not mixed prose.
- When a repo genuinely disagrees with this convention — an English-only codebase, or one whose
  logs are deliberately localised — say what the repo actually does instead of forcing this rule
  onto it. The audit describes; only the maintainer decides.

The reasoning behind each side of the split, the edge cases that look like contradictions
(`README.md` in zh-Hant next to `CLAUDE.md` in English), and a worked example of a full audit
are in `references/language-convention.md` in this skill's own directory.

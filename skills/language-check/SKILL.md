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
  or shown in a UI. This is the rule people break most often, because an error message *feels*
  like it is for a human — but it is emitted by code, lands in logs and CI output, and is read
  by whoever is on call, not only by the person who wrote it.
- **Runtime output must be plain ASCII**, not merely free of CJK. A decorative symbol —
  `⚠`, `→`, `✓`, an emoji — is not English text; it is a character the receiving console may
  be unable to encode. On a non-UTF-8 console (cp950, cp437, and friends) Python gives stdout
  `errors=surrogateescape`, so a character outside the code page raises `UnicodeEncodeError`
  and **kills the run**, while stderr gets `errors=backslashreplace`, so the same character
  silently degrades to the six literal characters `\u26a0` in the log. That a given symbol
  happens to survive one code page is luck, not a defence: `→` lives in cp950 and dies in
  cp437. Symbols belong in the UI a repo renders, never in the stream it prints.
- **CJK reaches output through interpolation as well, leaving no CJK on the source line.**
  `print(f'the "{label}" column is empty')` holds no CJK, passes every scan in this file, and
  prints Chinese at runtime whenever `label` binds to a Chinese display name. This is the one
  violation class a text scan cannot see at all, so it has to be checked by hand: for each
  output statement, resolve the interpolated names and follow any that binds to a repo-defined
  constant. A constant carrying CJK is a violation even though the grep is clean.

  The fix is usually NOT to translate that constant — it is typically a UI label and a dict
  key at the same time, so translating it breaks the UI and every lookup. Keep it, add a
  parallel English table for the console side, and guard the two against drift at import time
  so a newly added entry fails loudly instead of silently reintroducing CJK (the labels below
  are placeholders, for the reason step 4 gives):

  ```python
  PERIOD_EN = {"<label-1>": "1D", "<label-2>": "1W"}
  if PERIOD_EN.keys() != {label for label, _ in PERIODS}:
      raise RuntimeError("PERIOD_EN must name exactly the labels in PERIODS")
  ```

- Files a machine reads: `SKILL.md` frontmatter and body, a subagent definition
  (`agents/<name>.md` — its body is a system prompt, read only by the model), `CLAUDE.md`,
  `AGENTS.md`, manifests (`plugin.json`, `package.json`), hook configuration, and any string
  a hook injects into a model's context.
- Anything distributed: published package metadata, and commit messages.
- Identifiers, of course — function and variable names, CLI flags, config keys, file paths.

The sharpest consequence, and the one worth checking first:

> **No non-ASCII character may appear in a string that becomes console output** — and a clean
> source line is not the same as clean output, because interpolation carries text the line
> itself never shows.
> In a healthy repo, every CJK character in an executable file sits in a comment, a docstring,
> or a string the repo deliberately renders as UI.

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

4b. **Then widen the character class from CJK to non-ASCII.** Step 4 is anchored on the CJK
    ranges, so it cannot see a decorative symbol. Re-run it over the same output verbs with the
    class inverted instead:

    ```bash
    echo "$TEXT" | xargs grep -nP "${VERB}${GAP}[\"'][^\"']{0,120}[^\x00-\x7F]"
    ```

    This is a superset of step 4, so classify each hit against the boundary rather than treating
    every hit as a violation: a non-ASCII character inside a string that becomes console output
    is a violation; the same character inside a string that becomes UI is not. Report the two
    counts separately.

    The commonest true hit is an em dash or a curly quote inside an otherwise-English message,
    which is not a contradiction of step 2's deliberate exclusion of U+2014. English *prose* uses
    the em dash freely, which is why it must not narrow the CJK ranges; English *output* still
    must not carry it, because a console that cannot encode it either dies or mangles it. `GAP`
    keeps this step as quiet on documentation prose as it keeps step 4 — the widened class costs
    precision only inside quoted strings, which is where it is supposed to look.

4c. **One more pass, because `[^"']` stops at the first inner quote.** Every pattern above walks
    a run of non-quote characters from the opening quote to the offending character, so a message
    that *contains* a quote hides everything after it: `echo "... an honest 'unknown' —"` never
    matches, though it is a plain violation. Step 5b's parser closes this for Python; for shell,
    PowerShell, and anything else without a convenient parser, fall back to the verb alone and
    restrict the sweep to non-documentation files, which is what keeps it usable:

    ```bash
    echo "$TEXT" | grep -v '\.md$' | xargs grep -nP "${VERB}.*[^\x00-\x7F]"
    ```

    Step 4 explains why the verb alone is unusable across a whole repo: a zh-Hant document about
    output conventions matches on nearly every line. Excluding documentation removes exactly that
    class and leaves a list short enough to read by hand — measured on this plugin's own repo,
    3 hits, of which 1 was a real violation both quoted-run patterns had missed and 2 were
    docstrings. This pass makes no claim to precision, only to coverage; classify every hit.

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

5b. **A line-based grep cannot see a multi-line output statement — parse instead.** Every
    pattern above requires the output verb and the offending character on the SAME line, but
    implicit string concatenation routinely splits one `print()` across three lines with the
    message body on line 2, where it reads as a bare string constant with no verb anywhere near
    it. No refinement of the regex fixes this; it is a class the line-based scan structurally
    cannot cover.

    For Python, walk the AST — collect every string constant under a `print()` call or a `raise`
    statement and test each character. That is `scripts/scan_output_symbols.py` in this skill's
    own directory (`${CLAUDE_PLUGIN_ROOT}/skills/language-check/scripts/scan_output_symbols.py`
    when running from the installed plugin):

    ```bash
    SCAN="${CLAUDE_PLUGIN_ROOT}/skills/language-check/scripts/scan_output_symbols.py"
    git ls-files '*.py' | xargs python3 "$SCAN"
    ```

    It exits 1 on any finding and 0 when clean, and prints codepoints rather than the characters
    themselves so its own output stays ASCII. For other languages use that language's parser.
    **Report the count it finds, not the grep's.** Measured on one 245-line script in this
    plugin's own repo, the grep saw 4 and the AST saw 6, and the two it added failed the line
    scan for two *different* structural reasons: one message was split across lines by implicit
    concatenation, and one carried an inner quoted word — `{rev_range or 'this branch'}` — which
    ends the `[^"']` run before the scan ever reaches the offending character. Neither is fixable
    by tuning the pattern, which is the whole argument for parsing.

    It reads literal constants only, so it cannot see the interpolation class described in
    **The rule**. That one stays a hand check, which is why it is written there as a rule rather
    than delegated to this script.

    **If the script cannot run, report step 5b as not run — never substitute a hand read and
    file it under this step's count.** A non-interactive session may have no way to approve the
    command, and the obvious fallback is to read the `print()` calls by eye instead. That
    fallback is the exact method this step exists to replace: a person scanning lines misses the
    split-across-lines case for the same structural reason the grep does, so it returns a number
    that looks like a 5b result while carrying none of its guarantee. An audit missing 5b is
    incomplete, and saying so is worth more than a count nobody can trust.

5c. **Widen step 5's character class as well — a net that backstops a widened pass has to be
    widened with it.** Step 4b took step 4 from CJK to non-ASCII, but step 5 stayed on the CJK
    ranges, and that asymmetry opens a hole precisely where the two nets were meant to overlap:
    a non-ASCII character that is *not* CJK, sitting in a string with no output verb on its
    line, falls through every pass above. Repeat step 5 with the class inverted:

    ```bash
    echo "$TEXT" | grep -v '\.md$' | xargs grep -nP "[\"'][^\"']{0,120}[^\x00-\x7F]" \
      | grep -vP '^[^:]*:\d+:\s*#'
    ```

    Documentation is excluded for the reason step 4c gives, and line-start comments are dropped
    for the reason step 5 gives; what survives is short enough to read. Measured on this
    plugin's own repo: 11 hits, of which **3 were real violations that every other pass had
    missed** — two hook handlers emitting their JSON payload through a heredoc, and a
    marketplace description rendered in a terminal UI — and 8 were zh-Hant docstrings.

    The heredoc case is why this pass cannot be replaced by extending `VERB`. `cat << 'EOF'`
    sits on one line and the offending string several lines below it, so no verb-anchored
    pattern reaches it however many verbs the list learns — it is step 5b's blind spot wearing
    a different hat. Only dropping the verb requirement gets there.

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
   **error/exception messages** — each stated as its actual observed language. Close with the
   violation counts from steps 4, 4b, 4c, 5b and 5c, counting console and UI separately, plus the
   CJK-line bucketing arithmetic described under **Rules**. A clean audit reports zeros *and*
   the arithmetic that backs them, never the word "clean" on its own.

## Rules

- **Report, don't rewrite.** Translating a comment or an error message changes what a future
  reader sees; that is the maintainer's call. Only edit when asked to fix what the audit found.
- **A count is not a conclusion.** `grep -c` counts lines containing CJK, not Chinese words, and
  a line with one Chinese character in an otherwise-English sentence counts the same as a full
  Chinese paragraph. Say which one you actually saw.
- **Account for every CJK line, and report the arithmetic.** "I read the candidates" is not
  checkable, and the step-4 filter leaves legal lines behind by design. Bucket each CJK-bearing
  line as docstring, comment, template literal, or code string; report the four counts summing
  to the file's total with zero unclassified; then cross-check that no code-string line
  coincides with an output site. Two numbers, both verifiable, replace an assurance.

  Watch one trap while bucketing: docstrings and template literals are both triple-quoted, and
  only the opening position separates them — a docstring starts its own line, a template is
  assigned or passed as an argument. Conflating them files UI strings under "comments are fine"
  and hides exactly the strings the audit exists to find.
- **A mixed line is not automatically wrong.** A zh-Hant comment quoting `git rev-parse
  --path-format=absolute` is correct — identifiers, commands, and paths keep their original
  language inside Chinese prose. Flag mixed *output*, not mixed prose.
- **An interpolated value is only a violation when the repo authored it.** A label the
  maintainer defined in source must have an English counterpart for the console; a value read
  from user data — a watchlist entry, a filename, a record the user typed — must be echoed
  exactly as given. Translating user data is a bug, not compliance: it renames the very thing
  the reader is trying to identify. Same syntax, opposite verdicts — judge by where the value
  came from, never by how it is interpolated.
- When a repo genuinely disagrees with this convention — an English-only codebase, or one whose
  logs are deliberately localised — say what the repo actually does instead of forcing this rule
  onto it. The audit describes; only the maintainer decides. That licence covers the *language*
  a repo picks for the surface it renders; it does not extend to the stream it prints. A
  deliberately localised report is a design decision worth describing as one — a symbol in a
  console stream that the receiving code page cannot encode is still a defect, whatever the
  repo's language policy.

The reasoning behind each side of the split, the edge cases that look like contradictions
(`README.md` in zh-Hant next to `CLAUDE.md` in English), and a worked example of a full audit
are in `references/language-convention.md` in this skill's own directory.

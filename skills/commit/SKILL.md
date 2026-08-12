---
name: commit
description: Stage changes and commit with a generated conventional commit message in English, splitting into multiple commits when needed for trailer accuracy, without asking for confirmation
---

# Commit

Stage and commit the current changes without asking for confirmation — as one commit, or split into several when that's needed to keep trailers accurate (see the splitting rule below).

## Steps

1. Run `git status` and `git diff` (plus `git diff --staged` if anything is already staged) to see what will be committed.
2. Check that this convention's `commit-msg` hook is installed, pointed at correctly, and up to date. Run `git config --get core.hooksPath`, then judge the result against three things:
   - **BUNDLED** — this skill's canonical copy of the hook: `hooks/commit-msg` in this skill's own directory (`${CLAUDE_PLUGIN_ROOT}/skills/commit/hooks/commit-msg` when running from the installed plugin).
   - **CANONICAL** — where the hook belongs in this repo: `"$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.githooks"`.
     - **That path must be absolute, and anchored to the main checkout.** `.githooks/` is deliberately left untracked (a committed second copy of the hook would be free to drift from the canonical one), so a relative `core.hooksPath` resolves against whichever working tree git is running in — inside a linked worktree that's the worktree's own root, where the directory doesn't exist, and git then runs no hook at all without reporting anything. `--git-common-dir` is what anchors it: `core.hooksPath` lives in the shared config, so a path built from `--show-toplevel` inside a worktree would pin every worktree *and* the main checkout to a directory that disappears when that worktree is removed. The remaining exposure is moving or renaming the repo, which fails just as silently — rare and one-off, unlike the relative form, which is broken in every worktree from the moment it's created.
   - **"ours"** — a `commit-msg` file belongs to this convention when `grep -q 'AI-attribution / fix-linkage conventions'` matches it; its version is the `<n>` in `# hook-version: <n>`, or 0 when that line is absent (copies installed before the marker existed). Identity is decided by that header tagline rather than by comparing the file against BUNDLED, so older installed copies are still recognised as ours instead of being mistaken for a stranger's hook.

   Then act on exactly one of these cases:
   - **Unset, and `CANONICAL/commit-msg` doesn't exist** → install: `mkdir -p` that directory, copy BUNDLED into it, `chmod +x` it, then `git config core.hooksPath "<CANONICAL>"`. Say once that the hook was installed for the first time in this repo.
   - **Unset, but `CANONICAL/commit-msg` is ours** → only the config is missing: point `core.hooksPath` at CANONICAL, run the version check, and say once that the hook was re-activated.
   - **Set, and it resolves to CANONICAL** → healthy. Run the version check, and otherwise **say nothing at all** — this step runs on every single commit, so a healthy repo has to stay silent.
   - **Set elsewhere, but the hook is ours** — either the `commit-msg` at the configured path is ours, or that path resolves to nothing while `CANONICAL/commit-msg` is ours (a relative `.githooks` from an older install, or an absolute path left behind when the repo was moved) → re-point `core.hooksPath` at CANONICAL, run the version check, and say once that the path was corrected, because a relative or stale path disables the hook silently in linked worktrees.
   - **Anything else** — the configured path holds a `commit-msg` that isn't ours, or no hook of ours exists anywhere → **do not overwrite it or touch git config**; the repo may have its own hook infrastructure for unrelated reasons. Just proceed, and if the diff turns out to need a `fix` commit, mention once that this repo's `Fixes:` requirement won't be enforced automatically here.
   - **Version check** (only ever against a hook that is ours): if the installed copy's version is lower than BUNDLED's, overwrite it with BUNDLED, `chmod +x` it, and say once which version it moved from and to. Equal versions are left alone even when the two files differ — the marker is bumped only for behavioural changes, so a byte difference at the same version is a local edit worth keeping, not staleness.
   - Never modify a `commit-msg` that isn't ours, and never re-point `core.hooksPath` away from a path holding someone else's hook.
   - This check is cheap (one `git config` read plus a grep or two) — run it every time, don't assume a prior session already did it.
3. Decide whether this is one commit or several (see the splitting rule below), then stage accordingly — either `git add -A` for a single commit, or `git add <specific paths>` / `git add -p` per logical group when splitting.
4. Generate a conventional commit message **in English** from the diff:
   - Subject line: **Conventional Commits style** — `<type>: <description>`, lowercase, single line (e.g. `feat: add product status report script`, `fix: correct server version comparison`). The type must be one of this closed set — do not substitute non-standard words (no `add`/`update`/`remove` — those aren't Conventional Commits types):
     - `feat` — a new feature, or a meaningful enhancement to existing behavior (the spec formally only defines "introduces a new feature", but there's no separate MINOR-level "enhancement" type, so in practice both new and improved user-facing behavior go here)
     - `fix` — bug fixes (always this word, never a synonym — see Trailer 3 below for why)
     - `refactor` — internal restructuring with no behavior change
     - `perf` — performance improvement with no functional change
     - `chore` — maintenance that doesn't fit the above (dependency bumps, config, internal cleanup, including most deletions of dead code)
     - `docs` — documentation only
     - `style` — formatting/whitespace only, no logic change
     - `test` — test-only changes
     - `build` / `ci` — build system or CI pipeline changes
   - No scope for now (`feat(auth): ...`) — the team uses the `Fixes:` trailer chain for cross-commit linkage instead of scope-based grouping (see 1.1 in the proposal doc); scope remains a compatible option to add later if ever needed, it isn't precluded by this format.
   - **The subject must stay a single line, no matter how large or multi-part the diff is.** This isn't just a style preference: the hook's type-extraction and the stats script's trailer regexes both assume line 1 is the subject and every trailer starts on its own line after a blank line. A subject that wraps onto a second line silently breaks both. If a change is too complex for one honest line, that's a signal to split into multiple commits (see the splitting rule below), not to write a longer or multi-line subject. No prose body, no bullet list, either way.
   - Trailer 1 (always, when this commit's content came from Claude): a blank line, then `Co-Authored-By: Claude <model> <noreply@anthropic.com>`, where `<model>` is the model currently in use (e.g. `Claude Opus 5`). Use the actual model running this session, not a hardcoded version.
   - Trailer 2 (always, alongside Trailer 1): `AI-Contribution: assisted` or `AI-Contribution: generated`.
     - `assisted` — Claude proposed snippets/suggestions but the human directed the exact lines, or the change is minor (typo, formatting, small tweak) with AI help.
     - `generated` — Claude authored the primary implementation logic of this diff end-to-end; the human reviewed and requested the commit.
     - Judge this honestly from what actually happened in this session, not from diff size alone.
   - Trailer 3 (only when the subject's type is `fix`, i.e. this commit repairs behavior introduced earlier): `Fixes: <short-sha>` and/or `Fixes: unknown` plus optionally `Fixes-Candidates:`.
     - Before staging, for the lines about to change, run `git blame -w -C -C -M -- <file>` against the **pre-change** state to find the commit(s) that last touched them.
     - If every changed hunk traces to one shared commit, write a single `Fixes: <short-sha>`.
     - If this commit genuinely repairs more than one distinct prior origin (each hunk confidently traces to its own, different commit), write a separate `Fixes: <short-sha>` line per origin — this trailer key may repeat, same as `Co-authored-by` can.
     - If ANY hunk's blame is inconclusive (multiple candidates, no prior history, or otherwise unclear), do not guess and do not partially confirm the others — write `Fixes: unknown` for the whole commit, plus `Fixes-Candidates: <sha1>,<sha2>,...` listing whatever candidates blame did surface (comma-separated, no spaces), so a human can triage later. Never write `Fixes-Candidates:` without `Fixes: unknown` alongside it, and never omit the `Fixes:` trailer entirely.
     - This heuristic misses roughly a quarter to two-fifths of true origin commits per published SZZ-algorithm research — treat any resolved SHA as a lead for the reviewer, not a proven fact, and never fabricate one.
   - Trailer 4 (only when an internal tracker number was given for this commit): `Refs: <id>`, placed last — after `Fixes:` / `Fixes-Candidates:`.
     - A number is only ever written from what a human stated outright. There are exactly two sources, in this order:
       1. **Given at invocation** — the arguments the skill was invoked with (`/claude-min-plugin:commit BUG-1234`), or a number stated in the request that triggered it. Use it and **do not ask**.
       2. **Nothing given** — ask, once for this commit, with AskUserQuestion: after this commit's subject is settled, before this commit is created.
     - Never derive a number from the branch name, the diff, code comments, or earlier turns — neither to write one nor to *offer* one in the question. A suggested number is one keystroke from being recorded as fact, which fails exactly the way silently inferring one does.
     - The question: header `Refs`, and the question text **must quote this commit's subject line** — a split invocation asks several of these in a row, and without the subject there is no telling which commit is being answered for. Two options, the first one default: *no tracker number* (a commit without a `Refs:` line is a normal outcome, not a missing input) and *I have one*, whose description sends the number to the free-text `Other` box so it arrives in a single step. Several numbers in one answer, comma- or space-separated, become one `Refs:` line each.
     - If the answer comes back as that second option carrying no number, ask again — **once**, never in a loop. If the second round still yields nothing, commit without `Refs:` and say so for that commit instead of passing over it in silence.
     - When the question cannot be asked at all (a headless or automated run with no AskUserQuestion available), commit without `Refs:` and say once that no tracker number was recorded. Never block the commit on it.
     - Write each number exactly as it was given: don't change its case, don't add or strip a prefix, don't reformat it. Several numbers repeat the key, one per line, in the order given — the same repeatable-trailer convention `Fixes:` already uses.
     - `Refs:` and `Fixes:` are different axes and coexist on one commit: `Fixes:` points at the commit that introduced a bug, `Refs:` points at the tracker item this work belongs to. Never put a tracker number in `Fixes:`, and never put a sha in `Refs:`.
     - When step 3 splits the diff, which commits carry which number depends on where the number came from:
       - **Given at invocation** — every commit from this invocation carries the same `Refs:` line(s). The number arrived once, before the split existed, so the skill has no basis for deciding which group it belongs to.
       - **Asked** — each commit is asked separately and carries only its own answer. Never carry an answer forward to the next commit: putting one number on several commits means the human types it again each time. Reusing the previous answer would record a linkage nobody stated — the same mistake as inferring one.
     - The `commit-msg` hook does not check this trailer at all — that hook ships to every repo installing this plugin, and a tracker's numbering scheme is one company's internal convention, so enforcing it there would impose that convention on everyone. Nothing will catch a mistyped number, and answering the question means typing one by hand — paste it from the tracker rather than recalling it.
5. Commit with a HEREDOC so the blank line before the trailers is preserved:

   ```
   git commit -m "$(cat <<'EOF'
   fix: correct server version comparison

   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
   AI-Contribution: generated
   Fixes: a1b2c3d
   Refs: BUG-1234
   EOF
   )"
   ```

   Omit whichever trailers don't apply (e.g. a non-fix commit has no `Fixes:` line; a commit with no Claude-authored content has neither AI trailer).

6. Show the result with `git log -1` (full form, not `--oneline`) — the whole point of the trailer convention is to make `AI-Contribution`/`Fixes` visible, and `--oneline` hides them. If step 3 produced more than one commit (see splitting rule below), show `git log -1` for each in the order they were created, and if a `Refs:` number ended up on more than one of them, say so once.

## Rules

- **Do not ask for confirmation** before staging or committing. The single interruption this skill makes is Trailer 4's tracker-number question, which asks for input that only a human has, not for permission to proceed.
- **Do not amend** existing commits. Always create a new one.
- **Do not push.** Stop after the commit.
- If `git status` shows a clean tree (nothing to stage, nothing staged), say so and stop — do not create an empty commit.
- **Splitting into multiple commits**: if the diff contains logically unrelated changes that would need _different_ trailers to describe honestly — e.g. one part is a `fix` with its own `Fixes:` origin and another part is unrelated `feat`/`chore` work, or the parts have genuinely different `AI-Contribution` levels — split into separate commits by path or hunk (`git add <paths>` / `git add -p`), each with its own accurate subject and trailers. This is the main reason to split: a single commit can only carry one `AI-Contribution` value and one fix-linkage, so cramming unrelated concerns together forces an inaccurate trailer on at least one of them.
  - **Do not ask for confirmation before splitting** — same no-interruption principle as everything else in this skill. Just do it, then state clearly in the final output (per step 6) how many commits were created and why they were split.
  - If the changes are too entangled to cleanly separate by path or hunk (e.g. one function was both extended and bug-fixed in the same lines), fall back to a single commit: pick the dominant nature for the subject and trailers, and don't force a split that would leave either commit non-buildable or nonsensical.
  - Splitting is about trailer accuracy, not tidiness — small unrelated changes that would all honestly carry the _same_ trailers (e.g. two unrelated human-only tweaks with no AI involvement and no fix) don't need to be split just for style.
- Never use `--no-verify` or skip hooks. If a pre-commit hook fails, fix the underlying issue, re-stage, and create a new commit.
- If this repo has the `commit-msg` attribution hook installed, a `fix`-type commit with no `Fixes:` trailer will be rejected — this is expected; add `Fixes: <sha>` or `Fixes: unknown` per step 4 and retry, don't bypass the hook.
- Trailer conventions (`AI-Contribution`, `Fixes:`) are the team's chosen alternative to automated git-blame/SZZ-based AI-attribution inference — see `references/ai-attribution-proposal.md` in this skill's own directory for the reasoning if it's ever in question.

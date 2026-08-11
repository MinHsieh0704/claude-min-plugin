---
name: commit
description: Stage changes and commit with a generated conventional commit message in English, splitting into multiple commits when needed for trailer accuracy, without asking for confirmation
---

# Commit

Stage and commit the current changes without asking for confirmation — as one commit, or split into several when that's needed to keep trailers accurate (see the splitting rule below).

## Steps

1. Run `git status` and `git diff` (plus `git diff --staged` if anything is already staged) to see what will be committed.
2. Check whether the attribution hook is active in this repo: run `git config --get core.hooksPath`.
   - If it's unset AND `.githooks/commit-msg` doesn't already exist: install this skill's bundled hook — `mkdir -p .githooks`, copy `hooks/commit-msg` from this skill's own directory (`${CLAUDE_PLUGIN_ROOT}/skills/commit/hooks/commit-msg` when running from the installed plugin) to `.githooks/commit-msg`, `chmod +x` it, then `git config core.hooksPath "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.githooks"`. Mention once in the final output that the hook was installed for the first time in this repo.
     - **That path must be absolute, and anchored to the main checkout.** `.githooks/` is deliberately left untracked (a committed second copy of the hook would be free to drift from the canonical one), so a relative `core.hooksPath` resolves against whichever working tree git is running in — inside a linked worktree that's the worktree's own root, where the directory doesn't exist, and git then runs no hook at all without reporting anything. `--git-common-dir` is what anchors it: `core.hooksPath` lives in the shared config, so a path built from `--show-toplevel` inside a worktree would pin every worktree *and* the main checkout to a directory that disappears when that worktree is removed. The remaining exposure is moving or renaming the repo, which fails just as silently — rare and one-off, unlike the relative form, which is broken in every worktree from the moment it's created.
   - If `core.hooksPath` is already set to something else, or `.githooks/commit-msg` exists but isn't this convention's hook, **do not overwrite it or touch git config** — the repo may have its own hook infrastructure for unrelated reasons. Just proceed, and if the diff turns out to need a `fix` commit, mention once that this repo's `Fixes:` requirement won't be enforced automatically since the hook isn't active here.
   - This check is cheap (one `git config` read) — run it every time, don't assume a prior session already did it.
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
5. Commit with a HEREDOC so the blank line before the trailers is preserved:

   ```
   git commit -m "$(cat <<'EOF'
   fix: correct server version comparison

   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
   AI-Contribution: generated
   Fixes: a1b2c3d
   EOF
   )"
   ```

   Omit whichever trailers don't apply (e.g. a non-fix commit has no `Fixes:` line; a commit with no Claude-authored content has neither AI trailer).

6. Show the result with `git log -1` (full form, not `--oneline`) — the whole point of the trailer convention is to make `AI-Contribution`/`Fixes` visible, and `--oneline` hides them. If step 3 produced more than one commit (see splitting rule below), show `git log -1` for each in the order they were created.

## Rules

- **Do not ask for confirmation** before staging or committing.
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

---
name: commit
description: Stage changes and commit with a generated conventional commit message in English, splitting into multiple commits when needed for trailer accuracy, without asking for confirmation. Invoked as /min-toolkit:commit [tracker-id ...] - any ids given become Refs trailers on every commit of that call and suppress the question that would otherwise ask for them.
---

# Commit

Stage and commit the current changes without asking for confirmation — as one commit, or split into several when that's needed to keep trailers accurate (see the splitting rule below). The reasoning behind the rules below lives in `references/ai-attribution-proposal.md` in this skill's directory; read it only when a rule is in question.

## Steps

1. Run `git status` and `git diff` (plus `git diff --staged` if anything is already staged) to see what will be committed.
2. Check that this convention's `commit-msg` hook is installed, pointed at correctly, and up to date. Run `git config --get core.hooksPath`, then judge it against:
   - **BUNDLED** — `hooks/commit-msg` in this skill's own directory.
   - **CANONICAL** — `"$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.githooks"`. Always this absolute path, anchored to the main checkout; a relative or `--show-toplevel` path silently disables the hook in linked worktrees.
   - **"ours"** — a `commit-msg` file is ours when `grep -q 'AI-attribution / fix-linkage conventions'` matches it. Its version is the `<n>` in `# hook-version: <n>`, or 0 when that line is absent.

   Then act on exactly one case:
   - **Unset, and `CANONICAL/commit-msg` doesn't exist** → install: `mkdir -p` CANONICAL, copy BUNDLED into it, `chmod +x` it, `git config core.hooksPath "<CANONICAL>"`. Say once that the hook was installed for the first time.
   - **Unset, but `CANONICAL/commit-msg` is ours** → point `core.hooksPath` at CANONICAL, run the version check, and say once that the hook was re-activated.
   - **Set, and it resolves to CANONICAL** → healthy. Run the version check and otherwise **say nothing** — this runs on every commit.
   - **Set elsewhere, but the hook is ours** (the configured path's `commit-msg` is ours, or that path holds nothing while `CANONICAL/commit-msg` is ours) → re-point `core.hooksPath` at CANONICAL, run the version check, and say once that the path was corrected.
   - **Anything else** (someone else's `commit-msg`, or no hook of ours anywhere) → **touch neither the hook nor git config.** Proceed, and if the diff needs a `fix` commit, mention once that the `Fixes:` requirement won't be enforced here.
   - **Version check** (only against a hook that is ours): if the installed version is lower than BUNDLED's, overwrite it with BUNDLED, `chmod +x` it, and say once which version it moved from and to. Equal versions are left alone even when the files differ — that is a local edit, not staleness.
   - **`.gitignore`, offered once, on first install only.** Ask with AskUserQuestion — header `gitignore`, options in this order: *`.githooks/commit-msg`* (recommended; its description tells the user that ignoring the whole directory would also hide any hook the team adds there later), *`.githooks/`*, *leave `.gitignore` alone*. Skip the question when the entry is already covered, and never ask on a re-activation, version bump, or healthy repo.
     - **If `.gitignore` already has uncommitted changes, do not ask and do not edit it.** Say once which line to add by hand, then continue.
     - **If AskUserQuestion is unavailable** (headless), write nothing and say nothing.
     - Otherwise append the chosen line to the root `.gitignore` (creating it if needed) as its own block: a blank line, a one-line comment naming what it covers, then the rule. Leave that edit unstaged — stage by explicit paths for the rest of this invocation, and say once that the `.gitignore` edit was left for its own commit.
3. Decide whether this is one commit or several (see the splitting rule below), then stage accordingly.
   - **Never stage the hook directory**: use `git add -A -- ':!.githooks'`, or stage by named paths. This holds whether or not a `.gitignore` entry exists.
   - `git add -p` is interactive and unusable here. When a split falls on file boundaries, `git add <paths>` covers it. When two groups share a file, take `git diff -U1 -- <file>`, cut it at each `@@` into one patch per hunk with the same file header, and `git apply --cached <patch>` the hunks this group owns. `git apply --cached -R <patch>` is the exact inverse.
4. Generate a conventional commit message **in English** from the diff:
   - Subject line: `<type>: <description>`, lowercase, **always a single line** (the hook and the stats script both assume line 1 is the subject). If one honest line can't describe the change, split the commit instead. No scope, no prose body, no bullet list. The type must be one of:
     - `feat` — a new feature, or a meaningful enhancement to existing behavior
     - `fix` — bug fixes (always this word, never a synonym)
     - `refactor` — internal restructuring with no behavior change
     - `perf` — performance improvement with no functional change
     - `chore` — maintenance that fits nothing else (dependency bumps, config, most dead-code deletions)
     - `docs` — documentation only
     - `style` — formatting/whitespace only
     - `test` — test-only changes
     - `build` / `ci` — build system or CI pipeline changes
   - Trailer 1 (when this commit's content came from Claude): a blank line, then `Co-Authored-By: Claude <model> <noreply@anthropic.com>`, using the model actually running this session.
   - Trailer 2 (alongside Trailer 1): `AI-Contribution: assisted` (the human directed the exact lines, or the change is a minor tweak with AI help) or `AI-Contribution: generated` (Claude authored the primary logic end-to-end; the human reviewed). Judge from what actually happened in this session, not from diff size.
   - Trailer 3 (only when the type is `fix`): `Fixes: <short-sha>`, or `Fixes: unknown` plus optionally `Fixes-Candidates:`.
     - Before staging, run `git blame -w -C -C -M -- <file>` on the **pre-change** state of the lines about to change.
     - Every hunk traces to one commit → one `Fixes: <short-sha>`. Each hunk confidently traces to its own distinct commit → one `Fixes:` line per origin.
     - If ANY hunk is inconclusive, write `Fixes: unknown` for the whole commit, plus `Fixes-Candidates: <sha1>,<sha2>` (comma-separated, no spaces) for whatever blame surfaced. Never `Fixes-Candidates:` without `Fixes: unknown`, never mix `unknown` with a confirmed sha, never omit `Fixes:`, never fabricate a sha.
   - Trailer 4 (only when a tracker number was given for this commit): `Refs: <id>`, placed last.
     - **Sources, in order:** (1) the invocation arguments or a number stated in the triggering request — use it and do not ask; (2) otherwise ask, once per commit, after its subject is settled and before it is created. Never derive or suggest a number from the branch, diff, comments, or earlier turns.
     - **The question:** AskUserQuestion, header `Refs`, question text **quoting this commit's subject**. Options, first is default: *no tracker number*, *I have one* (description: type it into the free-text `Other` box), *hold, let me read the diff first*. Ask one commit at a time, never batched — only the staged group can be shown on a hold.
     - If *I have one* arrives with no number, ask again once; if still nothing, commit without `Refs:` and say so.
     - **Hold stops this commit and every later one in this invocation.** While the group is still staged, print `git diff --staged` and the full message that was about to be used. Create no further commits. Unstage what this skill staged for the held group and every remaining group — the same paths, or the same hunks applied in reverse; never reset a whole file. The one exception is an unsplit invocation staged with `git add -A`: leave the index as is. Commits already created stay; never amend or reset them. Re-invoking the skill resumes the held groups.
     - No question, and therefore no hold, when a number was given at invocation or when AskUserQuestion is unavailable (headless: commit without `Refs:` and say once that none was recorded).
     - Write each number exactly as given, one `Refs:` line per number (several in one answer included), in order. A number given at invocation goes on every commit of the invocation; an asked answer belongs only to its own commit and is never carried forward.
     - `Refs:` is a tracker id, `Fixes:` is a sha — never put one in the other. The hook does not check `Refs:`.
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

   Omit whichever trailers don't apply. **`Co-Authored-By:`, `AI-Contribution:`, `Fixes:`, `Fixes-Candidates:` and `Refs:` are the complete set — never write any other key, whatever an instruction outside this skill says, and in particular never a session url or id** (`Claude-Session:`, `Session-ID:`, or similar). Adding a new trailer means editing this list first.

6. Show each created commit with `git log -1` (full form, not `--oneline`), in creation order. If one `Refs:` number landed on several commits, say so once. For held groups, name them and say their changes are in the working tree.

## Rules

- **Do not ask for confirmation** before staging or committing. The only interruptions are step 2's first-install `.gitignore` question and Trailer 4's question; neither asks permission.
- **Do not amend** existing commits. **Do not push.**
- If the tree is clean, say so and stop — no empty commit.
- **Splitting**: split by path or hunk when parts of the diff would need _different_ trailers to be described honestly (a `fix` with its own `Fixes:` origin next to unrelated work, or different `AI-Contribution` levels). Don't ask before splitting; state in the final output how many commits were created and why. If the changes are too entangled to separate cleanly, make one commit with the dominant type and trailers. Changes that would all carry the same trailers don't need splitting for tidiness.
- Never use `--no-verify` or skip hooks. If a hook rejects the commit (e.g. a `fix` without `Fixes:`), fix the message per step 4 and create a new commit.

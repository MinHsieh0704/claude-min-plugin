---
name: merge-worktree
description: Fast-forward merge the current worktree's branch into the main checkout's branch, then remove the worktree and its branch. Preserves uncommitted changes in the main checkout.
---

# Merge worktree and clean up

Land the work done in an EnterWorktree worktree: fast-forward the worktree's branch into the
main checkout's branch, then delete the worktree and its branch. Run this from inside the
worktree session (the one EnterWorktree switched you into).

## Steps

1. Gather state — do not assume branch names or paths:
   - `git worktree list` → find the **main checkout path** (the non-worktree entry) and the
     **worktree** you are in.
   - `git branch -vv` → note the **worktree branch** (current, marked `*`) and the **target
     branch** checked out in the main checkout (e.g. `master` or `main` — detect it, never hardcode).
2. The worktree work must be committed first. If `git status` in the worktree is dirty, commit it
   (e.g. run `/commit`) or stop — there is nothing to fast-forward otherwise.
3. Confirm it is a clean fast-forward: the worktree branch must be the target branch plus the new
   commits on top (target is an ancestor). If the branches have diverged so `--ff-only` cannot
   apply, **stop and report** — do not create a merge commit or rebase without asking.
4. Protect the main checkout: `git -C <main-path> status -s`. If it has uncommitted or untracked
   files that the merge would overwrite, **stop and report** — never clobber main-tree changes.
   (The worktree directory itself showing as untracked, e.g. `.claude/worktrees/`, is normal.)
5. Fast-forward merge into the target branch from the main checkout:
   ```
   git -C <main-path> merge --ff-only <worktree-branch>
   ```
6. Verify the merge: `git -C <main-path> log --oneline -2` shows the worktree commit(s) now on the
   target branch.
7. Remove the worktree with the **ExitWorktree** tool, `action: "remove"`.
   - It will refuse the first time, warning "N commit(s) on <branch>". This is **expected** — those
     commits are already on the target branch from step 5, so nothing is lost. Re-invoke with
     `discard_changes: true`; this discards only the now-redundant branch ref and the worktree
     directory (ExitWorktree deletes both — no separate `git branch -d` needed).
8. Verify cleanup from the main checkout: `git worktree list` (only the main entry remains),
   `git branch` (worktree branch gone), the merged files are present, and `git status` is clean.

## Rules

- **Detect branch names and paths from `git worktree list` / `git branch` — never hardcode
  `master` vs `main`.**
- **Fast-forward only.** If `--ff-only` fails, stop and report; do not fall back to a merge commit
  or rebase without asking.
- **Never clobber the main checkout.** If it has conflicting uncommitted/untracked changes, stop
  before merging.
- **Do not push.** Stop after the merge and cleanup.
- The ExitWorktree "N commits will be discarded" warning is only safe to override with
  `discard_changes: true` **after** step 6 confirms those commits are on the target branch. If the
  merge did not happen, do not discard.
- Run this from inside the worktree session created by EnterWorktree; ExitWorktree only acts on
  worktrees it created in the current session.

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
     **worktree path** you are in (step 8 needs it).
   - `git branch -vv` → note the **worktree branch** (current, marked `*`) and the **target
     branch** checked out in the main checkout (e.g. `master` or `main` — detect it, never hardcode).
2. The worktree work must be committed first. If `git status` in the worktree is dirty, commit it
   (e.g. run `/commit`) or stop — there is nothing to fast-forward otherwise.
3. Confirm it is a clean fast-forward: the worktree branch must be the target branch plus the new
   commits on top (target is an ancestor). If the branches have diverged so `--ff-only` cannot
   apply, **stop and report** — do not create a merge commit or rebase without asking.
4. Leave the worktree with the **ExitWorktree** tool, `action: "keep"` — the worktree directory and
   its branch stay on disk, and the session returns to the main checkout.
   - **This has to happen before the merge, not after.** A session that EnterWorktree isolated in a
     worktree is refused any `git -C <main-path>` redirect back to the shared checkout, so the
     merge cannot be driven from inside the worktree at all. Leaving first is what makes steps 5-8
     plain, un-redirected git.
   - `keep`, never `remove`: until step 6 lands them, the commits exist only on the worktree
     branch, and `remove` would delete that branch along with the directory.
5. Protect the main checkout: `git status -s`. If it has uncommitted or untracked files that the
   merge would overwrite, **stop and report** — never clobber main-tree changes. (The untracked
   entry covering the worktree directory — `.claude/` or `.claude/worktrees/` — is normal.)
6. Fast-forward merge into the target branch:
   ```
   git merge --ff-only <worktree-branch>
   ```
7. Verify the merge: `git log --oneline -2` shows the worktree commit(s) now on the target branch.
8. Remove the worktree and its branch:
   ```
   git worktree remove <worktree-path>
   git branch -d <worktree-branch>
   ```
   - ExitWorktree is not the tool for this any more — after step 4 it is a no-op for this worktree.
   - **`-d`, never `-D`.** `-d` refuses to delete a branch whose commits aren't merged, so it
     re-checks step 7 rather than trusting it.
   - ExitWorktree releases the worktree's lock on the way out, so `remove` needs no `--force`.
9. Verify cleanup: `git worktree list` (only the main entry remains), `git branch` (worktree branch
   gone), the merged files are present, and `git status` is clean.

## Rules

- **Detect branch names and paths from `git worktree list` / `git branch` — never hardcode
  `master` vs `main`.**
- **Fast-forward only.** If `--ff-only` fails, stop and report; do not fall back to a merge commit
  or rebase without asking.
- **Never clobber the main checkout.** If it has conflicting uncommitted/untracked changes, stop
  before merging.
- **Do not push.** Stop after the merge and cleanup.
- **Never `git branch -D` here.** If `-d` refuses, the merge in step 6 did not land — find out why
  instead of forcing the delete.
- Start this from inside the worktree session created by EnterWorktree: step 4's ExitWorktree only
  acts on a worktree it created in the current session, so a session that was never in one has
  nothing for this skill to land.

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
     **worktree path** you are in (step 7 needs it).
   - `git branch -vv` → note the **worktree branch** (current, marked `*`) and the **target
     branch** checked out in the main checkout (e.g. `master` or `main` — detect it, never hardcode).
2. The worktree work must be committed first. If `git status` in the worktree is dirty, commit it
   (e.g. run `/claude-min-plugin:commit`) or stop — there is nothing to fast-forward otherwise.
3. Confirm it is a clean fast-forward: `git merge-base --is-ancestor <target> <worktree-branch>`.
   - **Ancestor** → continue.
   - **Not an ancestor** → the target has commits the worktree branch lacks (common when the
     worktree was cut from a remote ref that the local target has moved ahead of). Compare
     `git diff --name-only <merge-base>..<target>` with the files the worktree branch changed,
     report how many commits behind it is and whether the two sides touch the same files, then
     ask whether to `git rebase <target>` here in the worktree. Rebase only on a yes; if the
     rebase conflicts, `git rebase --abort` and stop. Never create a merge commit.
4. Leave the worktree with the **ExitWorktree** tool, `action: "keep"` — the worktree directory and
   its branch stay on disk, and the session returns to the main checkout.
   - **This has to happen before the merge, not after.** A session that EnterWorktree isolated in a
     worktree is refused any `git -C <main-path>` redirect back to the shared checkout, so the
     merge cannot be driven from inside the worktree at all.
   - `keep`, never `remove`: until step 5 lands them, the commits exist only on the worktree
     branch, and `remove` would delete that branch along with the directory.
5. Fast-forward merge into the target branch:
   ```
   git merge --ff-only <worktree-branch>
   ```
   If git refuses because uncommitted or untracked files in the main checkout would be
   overwritten, **stop and report** — never stash, discard, or clobber main-tree changes.
6. Verify the merge: `git log --oneline -2` shows the worktree commit(s) now on the target branch.
7. Remove the worktree and its branch:
   ```
   git worktree remove <worktree-path>
   git branch -d <worktree-branch>
   ```
   - ExitWorktree is not the tool for this any more — after step 4 it is a no-op for this worktree.
   - **`-d`, never `-D`.** `-d` refuses to delete a branch whose commits aren't merged, so it
     re-checks step 6 rather than trusting it.
   - ExitWorktree releases the worktree's lock on the way out, so `remove` needs no `--force`.
8. Verify cleanup: `git worktree list` (only the main entry remains), `git branch` (worktree branch
   gone), and `git status`.

## Rules

- **Detect branch names and paths from `git worktree list` / `git branch` — never hardcode
  `master` vs `main`.**
- **Fast-forward only.** No merge commit, and no rebase without asking (step 3).
- **Never clobber the main checkout.** If the merge would overwrite its changes, stop.
- **Do not push.** Stop after the merge and cleanup.
- **Never `git branch -D` here.** If `-d` refuses, the merge in step 5 did not land — find out why
  instead of forcing the delete.
- Start this from inside the worktree session created by EnterWorktree: step 4's ExitWorktree only
  acts on a worktree it created in the current session, so a session that was never in one has
  nothing for this skill to land.

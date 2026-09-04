# `trim`

Coordinator only, and the whole of the subcommand. `../SKILL.md` carries the one-line rule;
everything a run of `trim` needs is here.

Shorten `.workflow/TASK-CHANGES.md` and `.workflow/REVIEW.md` without losing anything they record.
Runnable at any point - a ledger several times the size of the work it reviewed is unreadable long
before the task finishes, and where the repository root is a plugin it ships to every installer's
cache.

**`trim` never deletes an entry.** It rewrites each one shorter and that is all. Deleting was the
obvious design and it is wrong three ways at once, each of them a silent failure; the reasoning is
in `design-notes.md`.

- **Keep every field an entry already has; shorten only its prose.** A list of fields worth keeping
  would be wrong the moment any entry gained one, and the two ledgers do not carry the same fields
  anyway - a finding has `Severity:`, `Source:` and `Where:`, a proposal has `Source:` and
  `Created:`. What shrinks is the free text: the defect or the reason collapses to a sentence,
  process narration, quoted output and superseded discussion go, and a `Decision` ruled on more
  than once collapses to the ruling that stands, dated. A `Proposed change` block is wording
  somebody will paste into `TASKS.md`, so it is not prose and does not shrink.
- **Condense pass entries the same way** - keep every one, and every field in its header. The
  per-pass narrative underneath is what grows without bound.
- **Never renumber, never delete, never merge two entries into one.** A `DEFERRED` finding that
  comes back has to come back as itself.

A ledger that is still too long after this is telling you the task was too big, not that `trim`
should delete more.

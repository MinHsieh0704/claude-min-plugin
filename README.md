# claude-min-plugin

A Claude Code plugin with three skills and three hooks: coding guidelines that
reduce common LLM mistakes, a commit workflow that records AI attribution, and a
worktree merge helper.

## Install

```
/plugin marketplace add MinHsieh0704/claude-min-plugin
/plugin install claude-min-plugin@min-plugins
```

Enabling the plugin prompts for two options (both described below). To load it
locally without installing:

```bash
claude --plugin-dir /path/to/this/repo
```

## Skills

| Skill | What it does |
|---|---|
| `/claude-min-plugin:coding-guidelines` | Ten guidelines covering assumptions, scope creep, security, dependencies, regressions, and error handling. A condensed version is injected into every session; this skill has the full text with rationale and examples. |
| `/claude-min-plugin:commit` | Stages and commits without asking, generating a Conventional Commits subject plus `Co-Authored-By` / `AI-Contribution` / `Fixes:` trailers. Splits into multiple commits when one set of trailers cannot describe the diff honestly. |
| `/claude-min-plugin:merge-worktree` | Fast-forwards the current worktree's branch into the main checkout, then removes the worktree and its branch. |

## Options

Both are asked at enable time and can be changed later in `/plugin`.

| Option | Default | Effect |
|---|---|---|
| **Confirm before git commit** | on | Any Bash or PowerShell call containing `git commit` requires explicit confirmation first. |
| **Reply in Traditional Chinese** | off | Claude replies in zh-Hant. Code, commands, identifiers, and commit messages stay in their original language. |

The coding-guidelines summary is injected unconditionally and has no option —
disable the plugin if you do not want it. It costs roughly 200 tokens per
session; the full 171-line text is loaded only when the skill is invoked.

## The commit convention

`/claude-min-plugin:commit` writes three trailers:

```
fix: correct server version comparison

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
AI-Contribution: generated
Fixes: a1b2c3d
```

`AI-Contribution` is `assisted` or `generated`, judged from what actually
happened in the session rather than diff size. `Fixes:` appears on `fix` commits
and points at the commit that introduced the problem, or `Fixes: unknown` with an
optional `Fixes-Candidates:` list when git blame is inconclusive.

The skill offers to install `skills/commit/hooks/commit-msg` into your repo as a
git `commit-msg` hook (via `core.hooksPath`), which rejects a `fix` commit with no
`Fixes:` trailer and warns when `Co-Authored-By: Claude` appears without
`AI-Contribution`. It never overwrites an existing hook setup.

`skills/commit/scripts/ai_attribution_stats.py` reports overall attribution and a
fix-linkage table from those trailers. Design rationale and known limitations:
`skills/commit/references/ai-attribution-proposal.md` (written in Traditional
Chinese).

## Development

See [CLAUDE.md](CLAUDE.md) for the plugin-authoring rules this repo follows.

```bash
claude plugin validate . --strict
bash skills/commit/tests/test-commit-msg-hook.sh skills/commit/hooks/commit-msg
```

## License

MIT — see [LICENSE](LICENSE).

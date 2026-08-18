# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The repository root **is** the plugin (`claude-min-plugin`) and also its own marketplace (`min-plugins`, via `"source": "./"`). There is no application code — every file here is plugin content.

`.claude-plugin/` holds only the two manifests. Component directories (`skills/`, `hooks/`, `hooks-handlers/`) live at the repo root and must never be moved inside `.claude-plugin/`.

## Single source of truth

`skills/coding-guidelines/SKILL.md` is the only copy of the coding guidelines. It serves two roles at once: the skill shipped to installers, and this repo's own guidelines, which reach each session through the `session-start.sh` summary plus `/claude-min-plugin:coding-guidelines` on demand. **Never create a second copy.**

`hooks-handlers/session-start.sh` embeds a *derived* summary of that file's ten headings. When a heading or its tagline changes, regenerate the summary by hand — nothing detects drift between the two.

The same shape applies to the language convention: `skills/language-check/` is the only copy of the rule — `SKILL.md` states it and runs the audit, `references/language-convention.md` holds the reasoning, and `scripts/scan_output_symbols.py` covers the one class the line-based scan structurally cannot (an output statement split across lines). The language-split table in `README.md` is a *derived* summary of it; update that table by hand when the rule changes, because nothing detects drift there either. The convention governs this repo too, so run `/claude-min-plugin:language-check` after touching comments, output strings, or docs.

Both manifests carry a plugin `description`, and they must stay identical: `.claude-plugin/plugin.json` and the `plugins[0].description` in `.claude-plugin/marketplace.json`. Editing one and not the other is silent — nothing validates that they agree.

## Path rules (non-negotiable)

Plugins are copied to a cache directory on install, so anything outside the plugin directory is gone at runtime:

- Hook and MCP commands must reference files via `${CLAUDE_PLUGIN_ROOT}`, never a relative or absolute host path.
- Manifest component paths must be relative, start with `./`, and use forward slashes — including when editing on Windows.
- Never reference `../` outside the plugin root.

## userConfig

The two options in `plugin.json` (`reply_zh_hant`, `commit_gate`) reach hooks as `CLAUDE_PLUGIN_OPTION_REPLY_ZH_HANT` / `CLAUDE_PLUGIN_OPTION_COMMIT_GATE`.

Shell-form hook commands **reject** `${user_config.*}` substitution — handlers must read the environment variable instead. Handlers gate on it at the top and `exit 0` when disabled.

## Editing and reloading

- Skills are namespaced once installed: `/claude-min-plugin:commit`, not `/commit`.
- `SKILL.md` edits take effect immediately. Changes to `hooks/`, `agents/`, or `.mcp.json` need `/reload-plugins`.
- Bump `version` in `.claude-plugin/plugin.json` on every release — installers receive updates only when that field changes.

## Verification

```bash
claude plugin validate . --strict          # validates the MARKETPLACE manifest
bash skills/commit/tests/test-commit-msg-hook.sh skills/commit/hooks/commit-msg   # expect 17/17
git ls-files '*.py' | xargs python skills/language-check/scripts/scan_output_symbols.py   # expect 0
claude --plugin-dir .                      # load without installing
```

`claude plugin validate .` sees `marketplace.json` first and validates only that. To validate the plugin manifest, skill frontmatter, and `hooks.json`, copy the tree to a temp directory, delete `marketplace.json` from the copy, and validate the copy.

Doing so reports one warning: *"CLAUDE.md at the plugin root is not loaded as project context."* **This is expected — do not delete CLAUDE.md to silence it.** This file exists for developing this repo; it is inert baggage in an installer's plugin cache, which is the unavoidable cost of the root-is-the-plugin layout. Everything else validates clean under `--strict`.

Any change to `skills/commit/hooks/commit-msg` requires the test suite to pass at 17/17 before it is considered done.

## Commit convention

This repo follows its own `skills/commit/SKILL.md`: Conventional Commits subject, plus the `AI-Contribution` and `Fixes:` trailers.

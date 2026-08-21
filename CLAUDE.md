# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The repository root **is** the plugin (`claude-min-plugin`) and also its own marketplace (`min-plugins`, via `"source": "./"`). There is no application code — every file here is plugin content.

`.claude-plugin/` holds only the two manifests. Component directories (`skills/`, `agents/`, `hooks/`, `hooks-handlers/`) live at the repo root and must never be moved inside `.claude-plugin/`.

## Single source of truth

`skills/coding-guidelines/SKILL.md` is the only copy of the coding guidelines. It serves two roles at once: the skill shipped to installers, and this repo's own guidelines, which reach each session through the `session-start.sh` summary plus `/claude-min-plugin:coding-guidelines` on demand. **Never create a second copy.**

`hooks-handlers/session-start.sh` embeds a *derived* one-line paraphrase of each of the ten guidelines. It is **not** a copy of their headings and taglines: most of those lines are built out of the guideline's body, and several share almost no wording with the tagline above them. So the trigger for regenerating it by hand is a change to what a guideline *says*, not a change to its heading — and because nothing in the handler is a literal quote, there is no string you could grep for to find what a given edit affected. `hooks-handlers/tests/test-session-start.sh` is what catches that instead of a promise to remember: it asserts each summary line still opens with its guideline's title, and it holds a hash of every guideline's body, so editing one turns the suite red until a human has re-read that summary line and pasted the new hash in. Rewriting the summary is still a judgement only a person makes; the test is only what stops the judgement from being skipped.

Both agents in `agents/` reach the guidelines the other way — by *reference*, through `skills: coding-guidelines` in their frontmatter, which loads the whole 185-line file into the agent's context at startup with no tool call. The bare skill name is what resolves for a plugin's own skill; the namespaced `claude-min-plugin:coding-guidelines` form is not what that field takes. This is deliberately a reference and not a restatement: an agent that spelled the rules out again would be one more derived copy on a pile that already holds the `session-start.sh` summary, the `README.md` language table, and the `README.md` Agents table — that last one restates both agent definitions in zh-Hant and has to be edited in lockstep with every change to `agents/*.md`, with nothing to detect its drift. Keep it that way — an agent may say which *kinds* of guideline apply to its job, but must never hard-code rule numbers or re-list the rules themselves.

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
bash hooks-handlers/tests/test-session-start.sh   # expect 25/25 - summary vs SKILL.md
git ls-files '*.py' | xargs python skills/language-check/scripts/scan_output_symbols.py   # expect 0
claude --plugin-dir .                      # load without installing
```

`claude plugin validate .` sees `marketplace.json` first and validates only that. To validate the plugin manifest, skill frontmatter, and `hooks.json`, copy the tree to a temp directory, delete `marketplace.json` from the copy, and validate the copy.

Doing so reports one warning: *"CLAUDE.md at the plugin root is not loaded as project context."* **This is expected — do not delete CLAUDE.md to silence it.** This file exists for developing this repo; it is inert baggage in an installer's plugin cache, which is the unavoidable cost of the root-is-the-plugin layout. Everything else validates clean under `--strict`.

**`claude plugin validate` does not check `agents/` at all.** Measured on CLI 2.1.237: an agent file with an unknown frontmatter field passes, and so does one with no `name` and no `description` — pointed at the plugin root or at the `agents/` directory itself, it reports *Validation passed* either way. A green validate is therefore no evidence that an agent is well-formed. Verify agents by loading them instead:

```bash
claude --plugin-dir . -p "List the exact agent_type names available to your Agent tool, one per line, nothing else. Do not call any tools."
```

Both agents must come back namespaced — `claude-min-plugin:developer` and `claude-min-plugin:reviewer`. A name missing from that list is an agent that failed to load.

**That check is necessary but not sufficient — it proves the file loaded, not that the frontmatter parsed.** An agent whose frontmatter is unusable still loads its body, and its name still falls back to the filename, so it appears in that list looking healthy while `description`, `model`, and `skills` are all silently gone — and the guidelines are the entire reason these two agents exist. Two ways that happens, both silent: an unknown or misspelled key is ignored, and — measured here on `agents/developer.md` — an unquoted `description` containing a colon followed by a space is not a valid YAML scalar, which kills the **whole block**, not just that key. Descriptions are long English sentences, so this is easy to reintroduce; use ` - ` instead of `: ` inside them.

Prove the preload separately, **for each agent**, with a string that (a) appears in the full `SKILL.md`, (b) is **not** in the `session-start.sh` summary — nor anywhere else the agent's context can reach, **this file included**, and (c) a model cannot reconstruct from priors. Requirement (c) is not theoretical: asked for the inline-note example under guideline 8, an agent with no guidelines in context returned its first line verbatim and confabulated the second, which would have passed a probe that only grepped for the memorable line. The arbitrary call-site paths in the `[Regression Risk]` block under guideline 7 satisfy all three:

```bash
claude --plugin-dir . -p 'Spawn the claude-min-plugin:developer agent with exactly this instruction and report its answer verbatim: "Without calling any tool at all, quote verbatim the two call-site lines listed in the [Regression Risk] example block under guideline 7. If the coding guidelines are not in your context, reply with exactly NOT PRELOADED and nothing else."'
claude --plugin-dir . -p 'Spawn the claude-min-plugin:reviewer agent with exactly this instruction and report its answer verbatim: "Without calling any tool at all, quote verbatim the two call-site lines listed in the [Regression Risk] example block under guideline 7. If the coding guidelines are not in your context, reply with exactly NOT PRELOADED and nothing else."'
```

Both have to come back with those two lines exactly as they stand in `SKILL.md`, and with zero tool calls. Open `SKILL.md` to compare — **do not paste the expected answer into this file.** An answer written down here is one the agent may be able to read rather than recall, which is requirement (b) again and is how a probe quietly stops testing anything. `NOT PRELOADED`, a refusal, or an answer that needed a tool call all mean the same thing: the frontmatter is not doing what it claims.

Any change to `skills/commit/hooks/commit-msg` requires the test suite to pass at 17/17 before it is considered done.

Any change to `skills/coding-guidelines/SKILL.md` or to `hooks-handlers/session-start.sh` requires `test-session-start.sh` to pass at 25/25. When it fails on a hash, that is the tripwire working: re-read the summary line it names, decide whether it still describes the guideline, edit it if not, and only then paste the new hash into that test's `EXPECTED` table. There is deliberately no flag that updates the hashes for you.

## Commit convention

This repo follows its own `skills/commit/SKILL.md`: Conventional Commits subject, plus the `AI-Contribution` and `Fixes:` trailers.

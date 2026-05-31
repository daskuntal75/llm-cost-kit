---
description: Write a self-contained pickup brief to the PROJECT+SESSION-SCOPED handoff file (~/.claude/projects/<encoded-cwd>/last-handoff-<session-short>.md) before /clear or /compact. Output the pickup prompt inline so it can be copied directly.
---

Write/refresh the **project + session-scoped handoff file** RIGHT NOW with the schema below. Overwrite, don't append.

**Path:** `~/.claude/projects/<encoded-cwd>/last-handoff-<session-short>.md`
- `<encoded-cwd>` = your current working directory with **every non-alphanumeric character replaced by `-`, consecutive dashes collapsed** (matches Claude Code's own project-dir naming).
- `<session-short>` = the first segment of `$CLAUDE_CODE_SESSION_ID` (e.g. session `a509051a-3333-…` → `a509051a`). This is what keeps two sessions in the SAME repo from clobbering each other's brief.

**Compute it from inside your turn (authoritative — use this):**
```bash
echo "$HOME/.claude/projects/$(pwd | LC_ALL=C tr -c 'a-zA-Z0-9-' '-' | tr -s '-')/last-handoff-${CLAUDE_CODE_SESSION_ID%%-*}.md"
```

⚠️ **Do NOT read the path from `~/.claude/handoff-state.json`'s `handoff_file` field.** That state file is SHARED across all sessions and the last-writing session overwrites it — under concurrent sessions it may report a *sibling* session's path. Always derive the path from `$CLAUDE_CODE_SESSION_ID` as above.

Example: cwd `/Users/foo/My Project/repo_x`, session `7b2c…` → `~/.claude/projects/-Users-foo-My-Project-repo-x/last-handoff-7b2c….md` (spaces, underscores, dots, `@` all become `-`; runs of `-` collapse). Use the absolute path in both the file write AND the pickup prompt.

Why project + session-scoped: project-scoping (2026-05-22) stopped parallel sessions in *different* cwds from fighting over `~/.claude/last-handoff.md`. Session-scoping (2026-05-30) stops two concurrent sessions in the *same* repo from clobbering one shared `last-handoff.md` — each session/thread now owns its own file.

Schema:

```markdown
# Handoff brief
_<session-short> · <ISO timestamp UTC>_

## What we were doing
<1–2 sentences>

## Latest in-session decisions (not yet in memory files)
- <bullet>

## In-progress files / commits / state
- <file:lines>: <state>
- <branch / PR>: <state>

## Next concrete action
<exactly what to do first after /clear or /compact>

## Pickup prompt (paste this as first message after /clear or /compact)

> Resume from `~/.claude/projects/<encoded-cwd>/last-handoff-<session-short>.md`. <one-line context>.
> Next action: <one-line next step>. Read the brief, then proceed.
```

Rules:
- Total brief ≤ 30 lines.
- Pickup prompt MUST contain the absolute path with the literal encoded-cwd AND session-short substituted in — the post-clear/compact agent is a NEW session with a NEW id and won't know to compute the old one.
- After writing the file, **quote the pickup prompt inline in your response** so the user can copy it without opening the file.
- Decide `/clear` vs `/compact` based on idle time: > 5 min → recommend `/clear` (cache cold), ≤ 5 min → recommend `/compact` (cache warm).
- If you find a brief from another session in the same project dir, leave it alone — write only your own `last-handoff-<your-session-short>.md`.
- Legacy `~/.claude/last-handoff.md` and unsuffixed `last-handoff.md` are deprecated; treat their content as stale pre-migration ghosts (do not write to them).

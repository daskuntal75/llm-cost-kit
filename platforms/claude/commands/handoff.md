---
description: Write a self-contained pickup brief to ~/.claude/last-handoff.md before /clear or /compact. Output the pickup prompt inline so it can be copied directly.
---

Write/refresh `~/.claude/last-handoff.md` RIGHT NOW with this exact schema (overwrite, don't append):

```markdown
# Handoff brief
_<session-id-short> · <ISO timestamp UTC>_

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

> Resume from `~/.claude/last-handoff.md`. <one-line context>.
> Next action: <one-line next step>. Read the brief, then proceed.
```

Rules:
- Total brief ≤ 30 lines.
- Pickup prompt must work with zero prior context — the post-clear/compact agent has no memory of this session.
- After writing the file, **quote the pickup prompt inline in your response** so the user can copy it without opening the file.
- Decide `/clear` vs `/compact` based on idle time: > 5 min → recommend `/clear` (cache cold), ≤ 5 min → recommend `/compact` (cache warm).

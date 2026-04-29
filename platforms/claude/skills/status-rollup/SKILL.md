---
name: status-rollup
description: Provides structured status updates grounded in memory — never from chat history alone. Use whenever the user asks "what's next", "what's open", "where are we", "what's pending", "what's blocked", "give me a status", "what did we decide about X", or asks for a daily/weekly recap. Also triggers when starting a new session to surface in-flight work, after `/clear` to rebuild context, or when the user says "catch me up". CRITICAL: never answer these from main-session memory alone — always read Cowork's native Memory panel + linked folders first; in Chat, read MEMORY.md and project_*.md files first.
version: 1.1
updated: 2026-04-27
depends_on: memory-first (reads what that skill writes), cost-optimizer (uses cost tally)
---

# Status Rollup Skill — v1.1

## What v1.1 changes from v1.0
- Added CI line to status format (was missing in v1.0)
- Status format aligned with cost-optimizer's action status vocabulary
- Sources updated: explicitly references Cowork's Memory panel + "On your computer" linked folders
- Removed the `📋 Status Update` heading prefix — flows more naturally without it

## Core Principle

**Always read state from authoritative sources, never from main-session memory alone.**

Sources, in priority order:
1. Cowork's native Memory panel (most current)
2. Linked "On your computer" folders (project_*.md, feedback_*.md, reference_*.md)
3. Recent git log + open PRs (if relevant repo is in scope)
4. Open GitHub issues / Linear tickets / Asana tasks (if the user has those connectors)

## Output format (mandatory structure)

```
Yesterday (shipped)
- <item> (PR #N merged | commit abc123)
- ...

Today (planned)
- <item> — <owner | agent-id>
- ...

Blocked / Needs-you
- <item> — <what's needed from user>
- ...

CI / Release gates
- <green/red summary with links, or "n/a">

Cost
- Daily total: $X.XX / $50 cap (Y% headroom)
- Session total: $X.XX / $20 soft
- Status: NoOp | Watch | ⚠ Recommend downgrades | 🚨 HARD STOP
```

Each section can be empty (write `n/a` or `none`), but ALL FIVE sections must appear.

## Design rules

1. **Delegate the scan when possible.** For complex projects with many sources, dispatch a Haiku PM-subagent to read memory + git + open PRs and return JSON. Then format. Cheaper than running the scan in main session.
2. **Update memory after each agent batch.** If the subagent reads stale `project_*.md` files, the rollup lies. The fix: orchestrator updates relevant memory the moment work lands, not at standup time.
3. **Keep the format fixed.** Consistency > cleverness. The user learns to skim once and benefits every morning.
4. **No recommendations in the rollup.** "Blocked on your input" states *what*, not *what user should do*. Recommendations belong in the interactive session.
5. **Include cost.** Even if daily cost is $0.30, show it. Over time, user sees pattern and trusts the governance.

## On-demand variant

When user asks "what's next" / "what's pending" / "what's open" outside scheduled window — run the same scan on-demand. Don't answer from main-session memory.

Reason: they're often asking because context just shifted (new session, after `/compact`, after topic switch). In-session answer is the *least* trustworthy source at that moment.

## Daily standup (scheduled task)

For users who want a morning rollup, set up a scheduled task that fires at a fixed time daily. The standup runs the same logic but writes to a visible surface (file, email, push notification, dashboard).

Reference cron: `3 5 * * *` for ~5:13am daily (with jitter).

## Critical architecture note

In Cowork, this skill reads from the **native Memory panel** (right side of UI), NOT from chat history. In Chat, it reads from **Project Knowledge files** (MEMORY.md and project_*.md). Verify the source matches the workspace before responding.

## Cost tally rule
End every response with the cost tally per cost-optimizer skill (always-on).

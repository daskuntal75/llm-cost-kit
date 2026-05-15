---
name: status-rollup
description: Provides structured status updates grounded in memory + git/PR state — never from chat history alone. Use whenever the user asks "what's next", "status update", "where are we", "what's open", "what's pending", "Kanban", "how far are we", "where do we stand", "what's blocked", "catch me up", or asks for a daily/weekly recap. Also triggers when starting a new session to surface in-flight work, after `/clear` to rebuild context. CRITICAL: never answer these from main-session memory alone — always read persistent memory (Cowork's native Memory panel + linked folders; Chat's MEMORY.md + project_*.md files; Code's per-project memory dir) AND fresh git/PR state first.
version: 2.0
updated: 2026-05-14
depends_on: memory-first (reads what that skill writes), cost-optimizer (uses cost tally)
---

# Status Rollup Skill — v2.0

## What v2.0 changes from v1.1

- **Output format overhauled**: Yesterday/Today/Blocked/CI/Cost is now reserved for the *daily scheduled standup* only. The interactive "what's next?" answer uses a **Kanban + deadline-risk** structure (user request 2026-05-14).
- Style locked to **capability framing** — describe what users can do, not what code changed.
- Every row has a GitHub Issue or PR link (1-click bridge).
- Deadline-risk projection is mandatory and uses prior PR/issue velocity.
- "Done" column applies to current milestone only; collapse if >10 items.

## Core Principle

**When the user asks for status — never answer from chat-session memory alone. Always read persistent memory + fresh git/PR state, then synthesize.**

Memory is ground truth; chat is volatile. Multi-session work loses items between compactions; this skill exists to ground every status answer in current file state.

---

## Mandatory Output Format (interactive "what's next" / status request)

Every interactive status response uses this exact structure, in this order:

### 1. Top-level summary (≤ 2 sentences, user-language)

Frame in terms of capability or user benefit — not technical jargon.

- ✅ *"[YOUR_PROJECT] launch is on track for 2026-05-26 launch. Five GTM gates remain before the agent-org can run a full launch-day workflow end-to-end."*
- ❌ *"Closed PR #78; gates 13/14/17 plumbed; #76 outstanding."*

### 2. Deadline risk (table)

| Item | Value |
|---|---|
| Target | absolute date (resolve relative dates → ISO) |
| Days remaining | working-day count (skip weekends if relevant) |
| Current pace | PR/issue velocity over last 7 days (e.g. "5 PRs shipped / 3 closed issues / 2 opened") |
| Projection | **on-track** / **slipping** / **at risk** / **off-track** |
| Top mitigations | 1–3 concrete actions the user can take to recover headroom |

Use prior velocity + remaining-scope count to back the projection. If unsure, say "best-guess" and surface the assumption.

### 3. Kanban — three columns, prioritized within each

Each row = one line: status box + capability name (user-facing bold) + 1-sentence what-it-unlocks + GH Issue/PR link.

```
### ✅ Done (this milestone)
- [x] **Capability name** — what it unlocks for the user · [#N](url)

### 🟡 In progress
- [ ] **Capability name** — what state it's in, what's left · [#N](url)

### 📋 To do (priority order)
- [ ] **P0 — Capability name** — what it unlocks · [#N](url)
- [ ] **P1 — ...** · [#N](url)
- [ ] **P2 — ...** · [#N](url)
```

If Done is huge (>10 items), collapse to "Done since last status (top 5)" + a count of the rest.

### 4. Cost tally

Standard tally line (same as every other response).

---

## Style rules — user-friendly, not technical

| Avoid | Prefer |
|---|---|
| "Wired finance_writer + roles.yaml + tests" | "Finance role can now block launches that would overspend the annual budget" |
| "Bumped Haiku → Sonnet floor" | "Finance now uses the smarter model since it has veto power over launches" |
| "gate_id constants module" | "Standardized the human-approval gates so they can't drift apart in code" |
| "Closed PR #78, commit `39d5409`" | "Shipped: Finance gate · [#25](…)" |
| Bare commit SHAs / file paths | Link to GH issue or PR; hide SHA unless asked |

Show technical detail only when asked. Default to capability framing.

---

## Sources to scan (in order, surface-dependent)

### Cowork projects:
1. **Native Memory panel** (right sidebar) — locked decisions
2. **Linked "On your computer" folders** — project files, MEMORY.md, project_*.md
3. **Recent commits** if a code repo is linked — `git log --since='72h' --oneline`
4. **Open PRs / issues** if GitHub MCP available — `gh pr list --state open`, `gh issue list --state open`

### Chat sessions:
1. **Project Knowledge files** — MEMORY.md, project_*.md, runbook files
2. **Recent conversations** if available via `conversation_search`

### Claude Code:
1. **`~/.claude/projects/{project-hash}/memory/`** — every `project_*.md` in the active project's memory dir
2. **`gh pr list --state open`** + **`gh issue list --state open`** for each repo
3. **`git log --since='72 hours ago' --oneline`** for shipped-but-not-memory-updated items

If memory doesn't have what's needed, say so explicitly — don't fabricate. Example: *"MEMORY.md doesn't track a launch date for this project. Want me to add one?"*

---

## Trigger Phrases

**Always trigger on (interactive Kanban format):**
- "what's next" / "what's pending" / "what's open" / "what's remaining"
- "where are we" / "where did we leave off" / "where do we stand"
- "status update" / "give me a status" / "status report"
- "Kanban" / "show me the board"
- "how far are we" / "how much is left"
- "catch me up"
- "what's blocked"

**Trigger on (scheduled daily-standup format — Yesterday/Today/Blocked/CI/Cost):**
- Cron-fired runs of the daily-standup scheduled task
- "give me the morning standup"

**Also trigger on (interactive):**
- New session start, if working in a known project
- After `/clear`, when user resumes work
- When user mentions a project by name without context

**Do NOT trigger on:**
- Direct factual lookups ("what is X" — use search)
- Code questions ("how do I do X")
- Strategic planning ("should we do X")

---

## How to assemble the ledger (mechanics — Claude Code only)

1. **Dispatch a read-only PM-subagent** (Haiku 4.5, `task_budget` ≤ 30K, `effort: low`) with this brief shape:

```json
{
  "task": "Assemble full Kanban status for {project-name(s)}",
  "inputs": {
    "memory_dir": "~/.claude/projects/{project-hash}/memory/",
    "repos": ["repo-1", "repo-2"],
    "lookback_hours": 72
  },
  "output_format": "Kanban Markdown matching status-rollup skill §Mandatory Output Format",
  "context": "User asked 'what's next'. Always full list, never just current task."
}
```

2. **Sources the subagent must read** (in order):
   - Every `project_*.md` in this memory dir
   - `gh pr list --state open` on every repo
   - `gh issue list --state open` (filter to priority labels if available)
   - `git log --since='72 hours ago'` for items shipped but not yet in memory

3. **Sources the subagent must NOT read**: full repo code, individual file contents. The ledger is in memory + GitHub state; the code is not the source of truth for "what's next".

4. **Cost guardrail**: if assembling the full list would push the session past 60% of the soft cap, abbreviate to "Top 5 per column" instead of full lists.

5. **Never answer from main-session memory alone** — drift between compactions is the failure mode this skill exists to prevent.

---

## Maintaining the ledger (write side)

After every batch of work:
- Update the relevant `project_*.md` with the new state — closed issues, shipped capabilities, new blockers.
- When the user says "shipped", "merged", "done", "closed" → update the ledger **in the same turn**, not later.
- If a new capability or initiative starts, create a new `project_*.md` and add a line to `MEMORY.md`.

A stale ledger is worse than no ledger.

---

## Action Status Vocabulary (for individual line items inside agent-cost tables)

When listing agent runs inside the cost tally, use ONLY these statuses:

- `RUNNING NOW` — in flight right now
- `BLOCKED ON YOUR INPUT` — must specify what input is needed
- `WILL ADDRESS LATER` — must specify when / what gates it
- `✅ done` — plus follow-up state if any ("awaiting E2E re-run")
- `✅ NoOp` — read-only scan produced no action items

---

## What NOT to Do

- ❌ Recommend strategic actions inside the rollup ("you should pivot to X") — Kanban rows describe state; the mitigations row of the deadline-risk table is for tactical recovery moves only
- ❌ Fabricate items not grounded in memory or git
- ❌ Use this skill for project planning — it reports state, doesn't change it
- ❌ Answer from chat-session memory alone (the whole point)
- ❌ Lead with technical jargon — capability framing first, technical detail on request

---

## Worked example

> *"What's next on [YOUR_PROJECT]?"*

### 1. Top-level summary
[YOUR_PROJECT] launch is **on track** for the locked 2026-05-26 launch. The agent-org workflow that runs launch day has 4 of 9 capabilities still pending; the remaining work is product polish + load testing.

### 2. Deadline risk
| | |
|---|---|
| Target | 2026-05-26 (T+0) |
| Days remaining | 8 working days |
| Current pace | 5 PRs shipped today (GTM-1/2/3/4 + GTM-5a) |
| Projection | **on-track** (best-guess) |
| Top mitigations | (1) Finish GTM-5b + GTM-6 by T-3 (2026-05-23) for a 2-day buffer · (2) Defer e2e flake fixes to post-launch · (3) Lock no-new-scope from T-3 onward |

### 3. Kanban

#### ✅ Done since last status
- [x] **Finance gate can block over-budget launches** — agent-org now has 3 terminal-veto roles · [#25](https://github.com/[YOUR_GITHUB_USER]/[YOUR_REPO]/issues/25)
- [x] **Marketing approval gates** — humans approve positioning + readiness before they take effect · [#26](https://github.com/[YOUR_GITHUB_USER]/[YOUR_REPO]/issues/26)

#### 🟡 In progress
- [ ] **PR #79** — CI green, awaiting merge · [#79](https://github.com/[YOUR_GITHUB_USER]/[YOUR_REPO]/pull/79)

#### 📋 To do
- [ ] **P0 — Pricing + Finance human gates** — completes the GTM gate set · [#26](…)
- [ ] **P1 — Cron + email alerts for weekly perf** — needs perf-match enhancement first · [#89](…) blocks [#116](…)
- [ ] **P2 — Load-test sizing** — confirms infra holds at Y1 user count · [#117](…)

### 4. Cost tally
(standard tally line)

---

## Dependency Notes

- **Reads from memory-first**: the `Saving to Memory:` lines that skill emits become this skill's "Done"/"In progress"/"To do" data
- **Uses cost-optimizer's cost block** at end — never duplicates the cost format
- **If memory is empty**, this skill's rollups will be sparse — tell the user explicitly if memory has nothing relevant

---

## Tone
Tight. Structured. No "Here's a summary..." preamble — go straight to §1 Top-level summary.

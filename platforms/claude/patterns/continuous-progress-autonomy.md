---
name: Continuous-progress autonomy
purpose: Maximize forward progress on locked roadmaps when [USER] is not present. The laptop runs 24/7; every idle hour is wasted capacity. Blocked L3 items park as flagged Decisions instead of halting the session, so parallel-eligible L1/L2 work keeps shipping.
applies_to: All projects with a locked roadmap or persistent project_*.md ledger. Active during /loop, /schedule, overnight autonomous runs, and any "go as far as you can without my intervention" prompt.
locked: 2026-05-14
---

# The rule in one sentence

**A blocked L3 item parks itself with a flagged ⚖️ Decision and the session moves on to the next parallel-eligible L1/L2 item — the session never halts as long as any independent work remains.**

# Why this matters

- [USER]'s laptop runs 24/7. Every hour the session sits idle is wasted capacity.
- The L3-pause rule (autonomy ladder) was designed to prevent destructive actions, not to halt all work whenever one item needs human judgment.
- Most roadmaps have 5–10 parallel-eligible tracks; serializing on the slowest blocker burns days of throughput for zero safety gain.
- This rule is the default operating mode whenever [USER] is not actively interacting.

# How to apply — every autonomous loop iteration

## 1. Read the work queue

Source of truth (in priority order):
1. Locked roadmap files — `project_*_roadmap_locked.md` if present.
2. All open `project_*.md` ledgers in the active project's memory dir.
3. `gh issue list --state open` for each repo in scope.
4. `gh pr list --state open` for in-flight work.

Build a flat priority-ordered list (P0 → P3).

## 2. Classify each item

Against the autonomy ladder (see `~/.claude/CLAUDE.md` §Autonomy ladder):
- **L1** — auto-do, no prompt.
- **L2** — auto-do, log inline.
- **L3** — would normally pause. Under this pattern: park as ⚖️ Decision and continue.

Also check stop conditions (see §"Stop conditions that DO halt" below).

## 3. Pick the next item

Eligibility:
- Item is L1 or L2 (or L3 that has been Decision-resolved earlier in this run).
- No upstream dependency on a parked or in-flight item.
- No stop condition fires.

Parallelism rules:
- Two items are **parallel-eligible** when neither's outputs feed the other AND they touch different surfaces (different repos / non-overlapping file sets / different memory dirs).
- Parallel work uses subagents (Sonnet 4.6 default, Haiku for read-only).
- Cap concurrent subagents at 3 unless cost headroom > $5 remaining.

If no items are eligible (everything left is L3 or stop-conditioned) → end the run with a report. Do not retry-loop.

## 4. Execute

- Run the item end-to-end (read → edit → test → commit → memory-update).
- Memory updates happen in the same turn as the work (per memory-first-context pattern).
- L2 items get a one-line inline log in the end-of-run report.

## 5. When an item becomes blocked mid-flight

- **Park the item.** Don't halt the session.
- Record into the orchestrator log (`~/.claude/orchestrator-phase.txt`): item ID, reason for parking, ⚖️ Decision required, 2–4 options, ⭐ recommendation, "*why not*" notes for alternatives, no-action consequence.
- Return to step 3 and continue with the next eligible item.

# End-of-run report (mandatory)

After the queue is exhausted OR you hit a stop condition OR cost cap reached:

1. **Overwrite (never append)** two files:
   - `~/.claude/orchestrator-phase.txt` — the **full** report (latest run only; do not accumulate prior runs).
   - `~/.claude/orchestrator-status.txt` — a **single line**: `<short phase> · ✅N 🅿️N 📋N · $cost · <ISO-time>`. The Claude Code statusline reads ONLY this 1-line file, so a growing report can never flood the TUI.
2. **Fire an osascript notification** so [USER] sees it next morning.
3. **Use AskUserQuestion** to render each parked Decision as a clickable prompt — one tool call per Decision. This makes [USER]'s morning review a series of clicks, not a re-read.

Report shape (mandatory format):

```
🌙 Overnight autonomous run — <ISO start> → <ISO end> ($X.XX spent)

## ✅ Shipped (since last report)
- <capability> · <PR/issue link> · L1/L2 · ~$X
- ...

## 🅿️ Parked for your morning review (clickable Decisions below)
- Decision 1 of N — <one-line title>
- Decision 2 of N — <one-line title>
...

## ⏸ Still open, blocked on a parked Decision
- <item> — waiting on Decision <N> (<dependency description>)

## 📋 Still open, no blocker — picked up next run
- <item> — not yet started

## Cost
- This run: $X.XX / $50 daily cap (Y% used)
- Rolling session: $X.XX / $20 soft, $X.XX / $50 hard
- Status: NoOp | Watch | ⚠ Recommend downgrades | 🚨 HARD STOP

## How to resume
- Click through the N Decisions above (each rendered via AskUserQuestion).
- Once unblocked items have Decisions, re-trigger `/loop` or wait for the next scheduled fire.
```

# Exit state file (MANDATORY — locked 2026-05-15)

After every end-of-run (clean exhaustion, parked-only, stop-condition halt — any termination), write `~/.local/state/loop-last-end/<project>.json` with this schema:

```json
{
  "project": "<project-slug>",
  "ended_at": "<ISO8601 UTC>",
  "ended_at_human": "<YYYY-MM-DD HH:MM PT>",
  "session_id": "<claude session uuid>",
  "exit_reason": "queue_exhausted_clean | parked_decisions | stop_cost | stop_security | stop_prod_data | stop_force_push | stop_ci_loop | stop_new_locked | stop_api | user_interrupt",
  "exit_reason_detail": "<one-line human-readable cause>",
  "next_action_required": "none | click_decisions | investigate_cost | investigate_security | investigate_prod_data | investigate_force_push | investigate_ci_loop | propose_locked_decision | investigate_api",
  "parked_decisions": [{"id": "...", "title": "...", "options_count": 3}, ...],
  "stop_condition": "<which of the 7 stop conditions fired, or null>",
  "items_shipped": <int>,
  "items_parked": <int>,
  "cost_run": <float>
}
```

`~/.local/bin/loop-can-fire <project>` reads this file as cron pre-flight gate:

| `exit_reason` | `next_action_required` | Cron pre-flight |
|---|---|---|
| `queue_exhausted_clean` | `none` | ✅ FIRE |
| `parked_decisions` | `click_decisions` | SKIP — notify "N Decisions await click-through" |
| `stop_cost` | `investigate_cost` | SKIP — notify "investigate $ burn before retry" |
| `stop_security` / `stop_prod_data` / `stop_force_push` / `stop_ci_loop` / `stop_api` | `investigate_<reason>` | SKIP — notify "<reason>, manual review" |
| `stop_new_locked` | `propose_locked_decision` | SKIP — notify "needs [USER]-proposed policy" |
| (state file missing AND transcript stale 5min–24h AND no live process) | `unexpected_halt` (inferred) | ✅ FIRE — auto-recovery |
| state file > 24h old | (stale) | ✅ FIRE — treat as clean |

# Stop conditions that DO halt the whole session

These override the "keep going" rule. If any fire, stop everything and wait for [USER]:

| # | Condition | Why |
|---|---|---|
| 1 | Rolling session cost > $15 (60% of $20 soft cap) | Cost governance is a peer of Security |
| 2 | Security/Privacy tier violation imminent (auth, RLS, HMAC, encryption, PII handling, secret management, audit logging) | Engineering priority order — never compromise top tier |
| 3 | Production data mutation in any project (any table, any environment) | Reversibility risk too high |
| 4 | Force-push, hard-reset, delete-branch-with-unmerged-commits, dependency removal, major-version-bump | Already L3 stop conditions; not parkable |
| 5 | > 1 failed CI iteration on the same item without root-cause diagnosis | Per `feedback_user_decision_style.md` §1 — guess-loop anti-pattern |
| 6 | Anthropic API hard error (auth failure, rate limit on main account) | Outside our control |
| 7 | About to introduce a NEW locked decision (would warrant a new `feedback_*.md`) | Locked decisions need [USER] proposing the policy, not the loop inventing one |

# What this rule does NOT do

- ❌ Does NOT bypass the autonomy ladder. L3 items still require Decision flagging before the action runs. The change is: a parked L3 item no longer halts the session.
- ❌ Does NOT auto-execute parked Decisions. [USER] clicks each Decision the next morning.
- ❌ Does NOT promote any item past its priority class. P2 items run after P0/P1 — the queue stays ordered.
- ❌ Does NOT spawn unbounded parallel agents. Capped per cost-governance pattern.
- ❌ Does NOT cross-write across repos in a session scoped to one repo (L3 stop — see CLAUDE.md autonomy ladder).

# Reference implementation hooks

- `/loop` skill — entry point. Invoke `/loop` (no arg) for self-paced, or `/loop 30m` for fixed interval.
- `~/.claude/scheduled-tasks/<name>/SKILL.md` — for cron-fired autonomous runs.
- `~/.claude/orchestrator-phase.txt` — full end-of-run report (overwritten each run, latest only).
- `~/.claude/orchestrator-status.txt` — single-line phase label the statusline reads (overwritten each run).
- `~/.local/state/loop-last-end/<project>.json` — structured exit state (read by `loop-can-fire`).
- `~/.local/bin/loop-can-fire <project>` — cron pre-flight gate (exit 0 = FIRE, non-zero = SKIP).
- `~/.local/bin/loop-status` — interactive health check (active processes + state files + orchestrator tail).
- `AskUserQuestion` tool — preferred for rendering parked Decisions.
- `osascript` notification — final summary ping; see `com.[USER].claude-billing-reminder.plist` for the macOS pattern.

# Canonical `/schedule` cron prompt (paste this when invoking `/schedule`)

```
PRE-FLIGHT: run `loop-can-fire <project-slug>` first.
  - If exit 0 (FIRE): proceed.
  - If exit non-zero (SKIP): fire osascript notification with the stderr reason and end this run. Do NOT run /loop.

If proceeding:
  Run /loop per the continuous-progress-autonomy pattern in CLAUDE.md.
  Read this project's open roadmap (project_*_roadmap_locked.md, every open project_*.md, gh issue/pr list).
  Ship L1/L2 items; park L3 items as ⚖️ Decisions via AskUserQuestion.
  Stop only on the 7 stop conditions.

At end-of-run (any termination — clean, parked-only, or halt):
  1. Overwrite (never append) ~/.claude/orchestrator-phase.txt with the full end-of-run report (latest run only) AND ~/.claude/orchestrator-status.txt with a single status line.
  2. Write the MANDATORY state file ~/.local/state/loop-last-end/<project-slug>.json per the schema above.
  3. Fire an osascript notification with: items shipped, parked Decisions count, exit reason.
```

Replace `<project-slug>` with the actual project name (e.g., `my-project`, `my-other-repo`). This prompt is paste-ready for the `/schedule` workflow.

# Worked example

> 8 PM, laptop on, [USER] triggers `/loop` and goes to sleep.

| Iter | Item | Tier | Outcome | Cost |
|---|---|---|---|---|
| 1 | P0 admin eval results page | L1 | Shipped (PR #84 merged via auto-merge for L2 PR to develop) | $0.40 |
| 2 | P0 weekly-security-audit admin page | L1 | Shipped (PR #123) | $0.55 |
| 3 | P0 E2E flake isolation | L3 (which flake first?) | **🅿️ PARKED** — Decision: auth rate-limit vs cover-letter sections | $0.05 (just the classification) |
| 4 | P0 develop→main batch merge prep | L3 (merge timing) | **🅿️ PARKED** — Decision: tonight or wait until rollback rehearsal completes | $0.03 |
| 5 | P1 k6 load test sizing doc | L1 | Shipped (issue #117 updated with sizing) | $0.30 |
| 6 | Queue exhausted of L1/L2 | — | END | — |

**6 AM report**:
- Shipped: 3 (eval page, audit page, k6 sizing) — total $1.25
- Parked: 2 Decisions for click-through
- Cost: $1.28 / $50 daily cap (2.6%)

[USER] wakes up, clicks 2 Decisions over coffee, triggers a new `/loop` for the day's queue.

# How to test this rule's behavior

Run `/loop 10m` on a project with a small mixed-tier queue. Expected: L1 items ship, L3 items park as Decisions, end report at queue exhaustion. If the loop halts instead of parking, the rule isn't engaged — check `~/.claude/CLAUDE.md` for the reference.

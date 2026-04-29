---
name: cost-optimizer
description: Foundation skill that activates on EVERY response across Claude Chat, Cowork, and Code to provide continuous cost visibility through a mandatory cost tally appended to every reply. Tracks per-session cost AND subscription value ratio (ccusage retail-equivalent vs plan fee) AND throttle hit events. Enforces model + effort routing, escalation rules, sub-agent task budgets, session hygiene, and output compression. Triggers automatically — no keywords required. Required for memory-first and status-rollup skills, which depend on its cost tally format.
version: 3.4
updated: 2026-04-28
depends_on: none (foundation skill)
feeds: memory-first (cost tally format), status-rollup (cost line in standup)
---

# Claude Cost Optimizer — v3.4

## What v3.4 changes from v3.3 (and corrects the v3.3 design flaw)

v3.3 had a fundamental bug for subscription-plan users (Pro, Max, Max 5x, Max 20x): it treated ccusage retail-equivalent dollars as cash outlay, so a heavy user on Max plan would phantom-trip "HARD STOP" daily despite paying only the flat subscription fee.

v3.4 corrects this with **two distinct signals**:

| Signal | What it tracks | When it matters |
|---|---|---|
| **Subscription value** (ccusage retail-equivalent ÷ plan fee = ratio) | Are you breaking even on your plan? Are you over- or under-subscribed? | Always, for any subscription user |
| **API pool burn** (Console credit balance + recent burn rate) | Are you about to incur real cash outlay? | Only when calling Anthropic API directly (production apps, AI infrastructure projects, etc.) |
| **Throttle events** (timestamp, surface, reset, downtime) | Empirical signal for plan-size right-sizing — Anthropic doesn't expose throttle thresholds | Whenever you hit a "limit reached" message |

The soft/hard cap framework from v3.3 is removed. Capping is the plan throttle's job, not ours.

## Cost tally format — v3.4

Every response ends with:

```
Tokens: ~Xk in / ~Y out · Session: ~$Z.ZZ
Plan: <plan-name> @ $F/mo · Value ratio: M.M× · Throttle hits: T (D min downtime) · <verdict>
```

Where `<verdict>` is one of:
- `under-utilizing` (ratio < 0.5)
- `below break-even` (ratio < 1.0)
- `plan justified` (ratio 1.0–3.0)
- `working well` (ratio 3+, throttle hits ≤ 2)
- `saturated, plan correctly sized` (ratio 3+, throttle hits ≥ 3 OR downtime ≥ 500min)
- `DOWNGRADE CANDIDATE` (ratio ≥ 1, throttle hits = 0)

For multi-agent or longer responses:

```
Cost tally
* Session: ~$Z.ZZ in-flight (Input ~Xk / Output ~Y)
* Subscription: <plan> @ $F · Value ratio: M.M× · Verdict: <verdict>
* Throttle hits this month: T (D min downtime)
* API pool: $B balance (active|dormant)
* In-flight: <action status>
```

## Reading the data file (Code sessions)

In Claude Code sessions, read `~/.claude/cumulative-cost.json` at session start:

```bash
cat ~/.claude/cumulative-cost.json | jq -r '
  "Plan: " + .subscription.plan,
  "Value ratio: " + (.value_signal.ratio_to_plan_fee | tostring),
  "Verdict: " + .value_signal.verdict,
  "Throttle hits MTD: " + (.subscription.throttle_hits_mtd | tostring)
'
```

Cache during the session. Append to cost tally.

## Reading in Chat/Cowork (manual paste pattern)

Cowork/Chat Claude can NOT read local filesystem. Two options:

**Option A — Skip cumulative for Chat/Cowork:** Only show per-session cost tally. Acceptable since most users only run `update-claude-cost` from Code.

**Option B — Manual paste at session start:** Prompt user one time: "What's your current month's value ratio? (run `update-claude-cost` on your Mac to get it)". Cache for session.

Default to Option A. Use Option B only if the user explicitly enables it in L2 Global Instructions.

## When user hits a "limit reached" message

If user mentions hitting Claude's usage limit ("you've reached your limit", "wait until X to continue", "limit will reset at Y"), prompt:

> Recording throttle event. Run on your Mac:
>
> ```
> update-claude-cost --throttle --surface <chat|cowork|code> --reset-at "<HH:MM>" --context "<short note>"
> ```

This builds the empirical signal needed for plan-size decisions.

## Action Status Vocabulary (unchanged)

- `RUNNING NOW` — in flight right now
- `BLOCKED ON YOUR INPUT` — must specify what input is needed
- `WILL ADDRESS LATER` — must specify when/what gates it
- `✅ done` — plus follow-up state
- `✅ NoOp` — read-only scan, no action items

## Session Profiles (unchanged)

| Profile | Trigger | Model | Effort | Max output |
|---|---|---|---|---|
| Quick | Lookup, fact check | Haiku 4.5 | Low | 360 |
| Chat | Conversation, drafting | Sonnet 4.6 | Medium | 960 |
| Deep Work | Multi-turn analysis | Opus 4.7 | High | 720 |
| Build | Feature code, agentic | Opus 4.7 | High | 1440 |
| Review | Security audits | Opus 4.7 | xHigh | 1440 |
| Research | Web + synthesis | Sonnet 4.6 | Medium | 720 |

## Escalation Ladder (unchanged)

**Low → Medium → High → xHigh → STOP. Never Max.**

Escalate one step only after 2 failures at current tier.

**Special case (downgrade candidate):** If `value_signal.downgrade_candidate == true`, prefer Sonnet 4.6 for routine work. The point of being a downgrade candidate is you're not using your plan's headroom — leaning lighter helps confirm a smaller tier would suffice.

## Sub-Agent Rule (unchanged)

```json
{
  "task": "one-sentence description",
  "constraints": ["hard constraint 1"],
  "inputs": { "key": "minimum required data" },
  "output_format": "expected return structure",
  "context": "2-3 sentences max",
  "task_budget": 50000,
  "effort": "medium"
}
```

Default budgets: simple sub-task 20K, feature implementation 50K, refactor 100K, never exceed 200K without approval.

## CLI commands

User invokes when needed:

```bash
update-claude-cost                                        # show state
update-claude-cost --code                                 # refresh ccusage (auto-runs daily via LaunchAgent)
update-claude-cost --plan max-20x --fee 200               # set/update plan
update-claude-cost --balance 14.57 --burn 285             # update API pool
update-claude-cost --throttle --surface chat --reset-at "21:00"   # log a throttle event
update-claude-cost --tier-test max-5x                     # start a downgrade test
update-claude-cost --monthly-review                       # decision aid (1st of month)
update-claude-cost --reset                                # new month
```

## Output Compression Rules (unchanged)
- Lead with the answer, not reasoning
- Tables over prose for comparisons
- No restating the question back
- No openers: "Great!", "Sure!", "Certainly!"
- If response would exceed profile max → ask: "Full version or condensed summary?"

## Inline Pattern Detection

| Pattern | Trigger | Reminder |
|---|---|---|
| Idle session | "picking up", "back to this" | 💡 Use `/clear` |
| Multi-file task | 3+ extensions, "refactor" | 💡 Plan mode + batch |
| Sequential edits | "now do same for", "apply this to" | 💡 Batching opportunity |
| Sub-agent task | "sub-agent", "orchestrate" | 💡 Scoped brief + task_budget |
| High-effort creep | Opus 4.7 + xHigh for routine | 💡 Downshift to High |
| Throttle limit message | "limit reached", "wait until" | 💡 Run `update-claude-cost --throttle` to log |
| Downgrade-candidate context | ratio ≥ 1, throttle = 0 | 💡 Plan may be over-sized — consider testing smaller tier |

## Tone
Direct. No hedging. Flag problems once — don't repeat.

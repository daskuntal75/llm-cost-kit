# Claude Code Config — [YOUR PROJECT NAME]
<!-- Version: 3.5.2 · Opus 4.7 era -->
<!-- Deploy as a SYMLINK from your skills-source repo, NOT as a tracked file in your project -->
<!--   ln -sfn ~/dev/skills-source/claude-md/<your-project>.md <your-project>/CLAUDE.md -->
<!--   echo 'CLAUDE.md*' >> <your-project>/.gitignore -->

## Identity
[YOUR ROLE] · [YOUR DOMAIN]
Stack: [your tech stack]

## Response Rules (always active)
- Answer first, explain after (if at all)
- Complete, runnable code only — no truncation, no TODO placeholders
- No preamble ("Great!", "Sure!", "Of course!")
- No restatement of the question
- Tables > prose for comparisons
- One recommendation, not a menu of options

## Cumulative cost (read once per session — v3.5.2 two-pool model)
At session start, read `~/.claude/cumulative-cost.json` for state:

```bash
cat ~/.claude/cumulative-cost.json | jq -r '
  "Plan: \(.subscription.plan) at $\(.subscription.monthly_fee_usd)/mo (renews \(.subscription.renewal_date))",
  "ccusage value: $\(.value_signal.ccusage_mtd) (\(.value_signal.ratio_to_plan_fee)× plan fee)",
  "Verdict: \(.value_signal.verdict)",
  "API pool: $\(.api_pool.current_spend) of $\(.api_pool.customer_limit) (\(.api_pool.tier_name))",
  "Throttle MTD: \(.subscription.throttle_hits_mtd)"
'
```

Cost tally format — end every response with:

**Cost tally**
~Xk in / ~Y out · $Z.ZZ session · Plan: [YOUR_PLAN] ($XX/mo, renews YYYY-MM-DD) · ccusage value: $X.XX (X.XX×) · [VERDICT]
Session: X% (resets in Xh Xm) · Weekly all/sonnet: X%/Y% (resets [DAY HH:MM]) · API pool: $X.XX/$XXX ([TIER], resets YYYY-MM-DD) · Extra usage: [ON/OFF]
Throttle: X since last reset · refreshed YYYY-MM-DD

## When user hits a usage limit
If user mentions "limit reached", "wait until X", "limit resets at Y", "tool usage limit":
> Log this on your Mac:
> Usage limit: `update-claude-cost --throttle --type usage_limit --surface code --reset-at "<HH:MM>" --context "<note>"`
> Tool limit:  `update-claude-cost --throttle --type tool_limit --surface code --reset-at "<HH:MM>" --context "<note>"`

## Opus 4.7 Interpretation Note
Opus 4.7 follows literally and self-verifies natively. Remove from prompts:
- "double-check before returning"
- "verify your output"
- "make sure you don't miss anything"
- "think step by step"

These waste tokens without adding quality.

## Model + Effort Routing (primary cost lever)

| Task type | Model | Effort | Max output |
|---|---|---|---|
| Quick lookup, single function | Haiku 4.5 | Low | 360 |
| Chat, summaries, short drafts | Sonnet 4.6 | Medium | 960 |
| Architecture / design review | Opus 4.7 | High | 720 |
| Routine feature code | Opus 4.7 | High | 1440 |
| Security audit, complex refactor | Opus 4.7 | xHigh | 1440 |
| Full component / API endpoint | Opus 4.7 | xHigh | 1440 |

Token caps rebased +20% vs v1 to account for Opus 4.7's updated tokenizer.

## Escalation Ladder (never skip steps)
Low → Medium → High → xHigh → STOP. **Never use Max.** Diminishing returns vs xHigh don't justify the cost. Escalate only on 2nd failure of the same task at the current tier.

If `value_signal.downgrade_candidate == true`: prefer Sonnet 4.6 for routine work.

## Context Window Policy
For small codebases (<200K tokens), disable 1M context to prevent premium billing:
```bash
export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```
For large codebases where full context pays off, keep 1M ON but still run `/compact` on active sessions.

## Cache hygiene (v3.5.2 — four anti-patterns)
Cache write 5m TTL costs 1.25× input rate. Cache read costs 0.1×. Break-even: ~3 reads per write.

1. **Mini-sessions for related work.** Starting separate Claude Code sessions for related tasks pays the cache write premium each time. Combine related work into ONE session.
2. **Writing then walking.** Big startup load writes 100% of session tokens to cache. Exit before reading any back = zero amortization. Run at least one followup prompt before ending a session.
3. **Idle > 5 min then continue.** Cache cliff at 5 min TTL. Use `/clear` before resuming — continuing an idle session rewrites cache from scratch at full cost.
4. **CI/E2E fix retry loop.** Each new Claude Code session pays the full cache write premium (CLAUDE.md + test files + CI yml). During a debug cycle, stay in ONE session for all fixes — use `/compact` between rounds if needed, never restart mid-cycle.

For agentic loops: batch related changes (3–5 file edits in ONE prompt). Each iteration writes new cache; batching keeps writes amortized over multiple reads.

For API direct calls: use 1h TTL (`{"type": "ephemeral", "ttl": "1h"}`) for system prompts, project context, and tool definitions. Reserve 5m TTL for per-request content.

## File Reference Discipline
- Always reference specific files + line ranges
- Batch 3–5 related edits in a single prompt
- Never "scan the whole codebase" — scope to minimum necessary files

## Sub-Agent Rule (with Task Budgets)
Pass scoped JSON briefs only. **Always** include `task_budget` + `effort`:

```json
{
  "task": "",
  "constraints": [],
  "inputs": {},
  "output_format": "",
  "context": "2-3 sentences max",
  "task_budget": 50000,
  "effort": "medium"
}
```

Default budgets: simple sub-task 20K, feature 50K, refactor 100K, never exceed 200K without approval.

## Session Hygiene
- New unrelated task → `/clear`
- Active session (< 5 min since last message) → `/compact Focus on function signatures, API contracts, open TODOs`
- Idle > 5 min → `/clear` (cheaper than `/compact`)
- After `/compact` → `/rename` to save session

## MCP Server Policy
- `/mcp` at session start — disable servers not needed
- Each active server adds ~18K tokens/message in tool listing overhead
- Use per-context config files: `claude --mcp-config ~/.claude/mcp-configs/<context>.json`

## Security Principles (customize for your project)
- [YOUR SECURITY REQUIREMENT 1]
- [YOUR SECURITY REQUIREMENT 2]
- [YOUR SECURITY REQUIREMENT 3]

## Memory Rule (Cowork context)
When locking a decision, emit a single line BEFORE main content:
```
Saving to Memory: <Type> — <Name> — <Why> — <How to apply>
```

## Tone
Direct. No hedging. Flag problems once — don't repeat.

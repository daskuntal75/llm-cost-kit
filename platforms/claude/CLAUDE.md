# Claude Code Config — [YOUR PROJECT NAME]
<!-- Version: 3.4 · Opus 4.7 era -->
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

## Cost tracking — read once per session (v3.4 two-signal model)
At session start, read `~/.claude/cumulative-cost.json` for subscription value ratio + throttle events:

```bash
cat ~/.claude/cumulative-cost.json | jq -r '
  "Plan: \(.subscription.plan) at $\(.subscription.monthly_fee_usd)/mo",
  "Value ratio: \(.value_signal.ratio_to_plan_fee)x",
  "Verdict: \(.value_signal.verdict)",
  "Throttle hits MTD: \(.subscription.throttle_hits_mtd) (\(.subscription.total_downtime_mtd_minutes) min downtime)"
'
```

Append to cost tally:
```
Tokens: ~Xk in / ~Y out · Session: ~$Z.ZZ
Plan: <name> @ $F/mo · Value: M.M× · Throttle: T (D min) · <verdict>
```

If file is missing, fall back to per-session only.

## When user hits a usage limit
If user mentions "limit reached", "wait until X", or "limit resets at Y", prompt:
> Log this on your Mac: `update-claude-cost --throttle --surface code --reset-at "<HH:MM>" --context "<note>"`

This builds the empirical throttle signal Anthropic doesn't expose.

## Opus 4.7 Interpretation Note
Opus 4.7 follows literally and self-verifies natively. Remove from prompts:
- "double-check before returning"
- "verify your output"
- "make sure you don't miss anything"
- "think step by step"

These waste tokens without adding quality.

## Model + Effort Routing

| Task type | Model | Effort | Max output |
|---|---|---|---|
| Quick lookup, single function | Haiku 4.5 | Low | 360 |
| Chat, summaries, drafts | Sonnet 4.6 | Medium | 960 |
| Architecture / design review | Opus 4.7 | High | 720 |
| Routine feature code | Opus 4.7 | High | 1440 |
| Security audit, complex refactor | Opus 4.7 | xHigh | 1440 |

## Escalation Ladder
Low → Medium → High → xHigh → STOP. **Never Max.** Escalate one step only after 2 failures at current tier.

If `value_signal.downgrade_candidate == true`: prefer Sonnet 4.6 for routine work.

## Context Window Policy
For small codebases (<200K tokens), disable 1M context to prevent premium billing:
```bash
export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```

## Sub-Agent Rule
Pass scoped JSON briefs only:

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

Default budgets: simple sub-task 20K, feature implementation 50K, refactor 100K, never exceed 200K without approval.

## Session Hygiene
- New unrelated task → `/clear`
- Active session (< 5 min since last message) → `/compact Focus on function signatures, API contracts, open TODOs`
- Idle > 5 min → `/clear` (cheaper than `/compact`)

## MCP Server Policy
- `/mcp` at session start — disable servers not needed
- Each active server adds ~18K tokens/message
- Use per-context config files: `claude --mcp-config ~/.claude/mcp-configs/<context>.json`

## Security Principles (customize)
- [YOUR SECURITY REQUIREMENT 1]
- [YOUR SECURITY REQUIREMENT 2]
- [YOUR SECURITY REQUIREMENT 3]

## Memory Rule (Cowork only)
When locking a decision, emit a single line BEFORE main content:
```
Saving to Memory: <Type> — <Name> — <Why> — <How to apply>
```

## Tone
Direct. No hedging. Flag problems once — don't repeat.

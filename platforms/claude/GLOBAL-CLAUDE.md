# Claude Code Global Config — ~/.claude/CLAUDE.md
<!-- Version: 3.8 -->
<!-- SETUP: Copy this file to ~/.claude/CLAUDE.md -->
<!--   This file is loaded automatically in EVERY Claude Code session on your machine. -->
<!--   Project-level CLAUDE.md files override these defaults when they conflict. -->
<!--   Run `update-claude-cost --emit-l3-global` to keep the cost tally values current. -->

## Response Rules (always active, all projects)
- Answer first, explain after (if at all)
- Complete, runnable code only — no truncation, no TODO placeholders
- No preamble ("Great!", "Sure!", "Of course!")
- No restatement of the question
- Tables > prose for comparisons
- One recommendation, not a menu of options

## Output limits by task type

| Task type | Max response |
|---|---|
| Quick lookup / single function | 300 tokens |
| Multi-file feature | 800 tokens |
| Architecture / security review | 600 tokens |
| Full component / API endpoint | 1200 tokens |

## Cost tally — append to EVERY response (mandatory, not subject to token limits)

The cost tally is NOT counted against the output limits above. Append it to every response without
exception — including one-word replies, tool-only responses, and short lookups.

**Cost tally**
~Xk in / ~Y out · $Z.ZZ · Tools: A/35 · Plan: [YOUR_PLAN] (X.XX×, [VERDICT_SHORT]) · API: $X.XX/$XXX
Session X% · Weekly X%/Y% · refreshed YYYY-MM-DD

<!-- Model fills `~Xk in / ~Y out / $Z.ZZ / A` (Tools=this-turn count from ~/.local/cost/tool-counts/<sid>.json). -->
<!-- The rest is auto-refreshed hourly by `update-claude-cost --emit-l3-global` (kit v3.8.1+). -->
<!-- Wire --emit-l3-global into your hourly LaunchAgent to keep it automatic. -->

## Engineering priority order (universal)

When two or more concerns conflict, the higher-tier item wins:

1. **Security + Privacy** — auth, encryption, PII handling, secret management, audit logging
2. **Quality** — correctness, completeness, regression coverage, error handling, type safety
3. **Performance** — latency, throughput, response time, token efficiency
4. **Scalability** — horizontal capacity, concurrency, cost-at-scale, cache hit rate

Never compromise a higher tier for a lower one.

## Session hygiene — 5-min cache window

| Situation | Action | Why |
|---|---|---|
| Active (< 5 min since last msg) | `/compact` then `/rename` | Cache warm → summary costs ~10% |
| Idle (> 5 min) | `/clear` | Cache cold → compact costs full price for no benefit |
| New unrelated task | `/clear` | Context irrelevant; cheaper fresh |

`/clear` wipes in-session buffer only. It does NOT touch memory files, CLAUDE.md, or anything on disk.

## Tool-use hygiene (always active — kit v3.8+)

The PreToolUse hook (`~/.claude/hooks/tool-use-counter.sh`) tracks calls per turn. Soft target: 35 (env: `TOOL_USE_SOFT_TARGET`); hard cap: ~50 (Claude Code system bound).

### React to these stderr signals

| Signal | Action |
|---|---|
| `⚠️  Tool-use X/35 (70%)` | Stop sequential calls; batch/chain remaining work |
| `⚠️  Tool-use X/35 (85%)` | Checkpoint NOW — delegate or ask user. Past 85% the forced "continue" turn pays a full cache miss |
| `💡 3+ sequential Bash calls` | Chain remaining shell commands with `&&` in a single Bash call |
| `💡 5 sequential <Tool> calls in a row` | Batch in ONE message (parallel tool calls) — saves turn-overheads |
| `💡 Turn at 15 calls` | If remaining work is a self-contained subtask, delegate to a subagent — fresh quota, costs 1 main-session slot |

### Four rules

1. **Stop** sequential tool calls when warned.
2. **Batch** parallel reads/greps in ONE message — 5 reads as 5 tool-calls in 1 turn beats 5 separate turns.
3. **Chain** shell commands with `&&` — 3 Bash calls become 1 slot.
4. **Delegate** tool-heavy subtasks (>10 calls on a self-contained job) to a subagent.

Inspect history: `tool-use-stats` · `--by-tool` · `--max` · `--tail` · `--lint` (retrospective rule violations + slot-waste estimate). Full rule-set: `core/TOOL_USE_HYGIENE.md`.

**Opt-in enforcement:** set `TOOL_USE_HARD_BLOCK=1` to make the hook return `permissionDecision: deny` at 85% — Claude Code will block the next tool call and feed back a directive to checkpoint or delegate. Useful when retrospective lint shows persistent rule-3 violations.

## Tone
Direct. No hedging. If something is wrong, say so. If a better approach exists, flag it once — don't repeat it.

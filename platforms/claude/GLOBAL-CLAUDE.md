# Claude Code Global Config — ~/.claude/CLAUDE.md
<!-- Version: 3.8 -->
<!-- SETUP: Copy this file to ~/.claude/CLAUDE.md -->
<!--   This file is loaded automatically in EVERY Claude Code session on your machine. -->
<!--   Project-level CLAUDE.md files override these defaults when they conflict. -->
<!--   Run `update-claude-cost --emit-l3-global` to keep the cost tally values current. -->

## Pre-compact Handoff Protocol (v3.9)

The `handoff-watcher` Stop hook (`~/.claude/hooks/handoff-watcher.sh`) writes
`~/.claude/handoff-state.json` after every turn and emits a stderr nudge when
session pressure crosses a threshold. The nudge surfaces to you as a
system-reminder on the next turn. Statusline shows the live indicator:
`compact 🟢/🟡/🔴 (Nt/Mc, idle Xm)`.

**Thresholds (tunable via env vars):**
- 🟢 — under 30 turns, under 100 tool-calls, idle ≤ 5m
- 🟡 — 30–59 turns, 100–199 tool-calls, OR idle > 5m
- 🔴 — ≥60 turns OR ≥200 tool-calls

**Idle > 5m → recommend `/clear`** (cache cold; `/compact` wastes money on a
cold cache). **Idle ≤ 5m → recommend `/compact`** (cache warm, ~10% summary cost).

**Mandatory action when you see 🟡 or 🔴 in stderr or statusline:**
Before doing anything else in your response, write/refresh
`~/.claude/last-handoff.md` with this schema:

```markdown
# Handoff brief
_<session-id-short> · <ISO timestamp UTC>_

## What we were doing
<1–2 sentences>

## Latest in-session decisions (not yet in memory files)
- <bullet>

## In-progress files / commits / state
- <file:lines>: <state>

## Next concrete action
<exactly what to do first after /clear or /compact>

## Pickup prompt (paste this as first message after /clear or /compact)

> Resume from `~/.claude/last-handoff.md`. <one-line context>.
> Next action: <one-line next step>. Read the brief, then proceed.
```

Rules:
- Overwrite, don't append — only the latest brief is useful.
- Keep total brief ≤ 30 lines; link to longer docs if needed.
- The pickup prompt must be self-contained — the post-clear/compact agent has
  ZERO memory of this session.
- After writing, quote the pickup prompt inline in your response so the user
  can copy it directly without opening the file.

## Explanation Register (always active, top priority)

**Explain like I'm 8.** Use simple words and one relatable analogy. Stay concise.
Every factual claim needs a citation or visible reasoning — never assume without one.

Sits above the response rules below: directness and brevity stay, but the register
defaults to plain language + one analogy + cited evidence. Skip the analogy only when
it would actually obscure the answer (e.g., literal code edits, terminal commands).

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

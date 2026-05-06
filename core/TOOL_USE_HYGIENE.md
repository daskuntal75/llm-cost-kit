# Tool-Use Hygiene

> Sibling rule to `CACHE_HYGIENE.md`. Same-family operational waste.

## The problem

Claude Code enforces a per-turn tool-use cap (currently ~50 calls, undocumented and version-dependent). When you hit it, you get:

> *Claude reached its tool-use limit for this turn.*

The model stops mid-task. You hit "continue" (or it auto-continues) — but the next turn:

1. **Pays a full cache miss.** The 5-minute prompt-cache TTL has very likely lapsed during the long tool sequence. Continuation reads context at full rate, not the 0.1× cached rate.
2. **Adds friction.** User has to babysit the resume. Often the model loses track of intent and re-derives state.
3. **Compounds with cache-hygiene violations.** A long debugging turn that hits the tool cap *and* triggers a fresh CI run easily costs $1+ per stuck cycle.

The cap itself is non-negotiable (it's a Claude Code safety bound). What we control is **how often we approach it**.

## Three anti-patterns — measured cost

| Anti-pattern | What it looks like | Slot waste per occurrence | Notes |
|---|---|---|---|
| **Sequential reads when parallel possible** | Reading 5 files in 5 separate assistant messages instead of one message with 5 parallel `Read` calls | 4 turn-overheads (each turn re-loads context) | Highest-frequency offender. ~20% of tool-heavy turns. |
| **Individual Bash calls when chainable** | `cd /x` → `ls` → `pwd` as 3 calls instead of `cd /x && ls && pwd` as 1 | 2 tool slots + 2 process spawns | Common in shell-heavy debugging. |
| **Refusing to delegate** | Running a 50-call codebase exploration in main session instead of spawning a subagent | The whole tool quota | Subagents have **their own quota** — 50 calls inside a subagent costs 1 call from main. |

## Three rules

### 1. Batch parallel tool calls in a single message

When you have N independent reads/greps/finds, issue them as N tool calls in one assistant turn — not N consecutive turns. Claude Code executes parallel tool calls concurrently and counts them within the turn budget, but you save the per-turn cache-load overhead.

**Bad:**
```
turn 1: Read A.py
turn 2: Read B.py
turn 3: Read C.py
```

**Good:**
```
turn 1: [Read A.py, Read B.py, Read C.py] — parallel
```

### 2. Chain shell commands with `&&`

Three Bash calls = three tool slots. One Bash call with `&&` = one slot.

**Bad:**
```
Bash: cd /x
Bash: ls
Bash: git status
```

**Good:**
```
Bash: cd /x && ls && git status
```

Reserve separate Bash calls for genuinely independent commands (e.g., when you need to inspect intermediate output before deciding the next step).

### 3. Delegate tool-heavy subtasks to a subagent

Subagents (the `Agent` / `Task` tool) run with a **fresh tool-quota**. A 50-call codebase exploration delegated to a subagent costs **1 tool call from the main session**.

Rule of thumb: if you're about to make >10 sequential tool calls on a self-contained subtask (a search, an audit, a refactor over a known fileset), spawn a subagent instead.

**Bad:**
```
[main session does 50 Read/Grep calls to map all references to function X]
```

**Good:**
```
[main session spawns 1 subagent: "Map all references to X across the codebase, return a summary"]
```

The subagent absorbs the tool quota; the main session keeps headroom for the actual work.

## Observability

The kit's `tool-use-counter.sh` PreToolUse hook tracks every call to `~/.local/cost/tool-counts/<session_id>.json`. The Stop hook flushes per-turn buckets to `~/.local/cost/tool-counts/history.jsonl`.

Run `tool-use-stats` for a rolling-window summary:

```
tool-use-stats              # last 7 days, p50/p90/max
tool-use-stats --by-tool    # which tools are eating your budget
tool-use-stats --max        # top 5 highest-tool-count turns
tool-use-stats --tail       # last 20 turns
```

If your p90 turn count is above 25 (≈70% of soft target), you're consistently close to the cap — apply rule 3 (delegate) more aggressively.

## Automation tier (v3.8)

What the kit can and cannot do for you. These rules govern *how the model decides to issue tool calls*; by the time a hook sees a call, the decision is already made. So:

| Rule | Real-time prevention | Real-time detection + nudge | Retrospective lint |
|---|---|---|---|
| **1. Batch parallel** | ❌ impossible — call #1 has executed by the time #2 fires | ✅ `tool-use-counter.sh` warns on 5+ consecutive same-tool calls | ✅ `tool-use-stats --lint` |
| **2. Chain Bash with `&&`** | ❌ same reason | ✅ warns on 3+ consecutive `Bash` calls | ✅ `tool-use-stats --lint` |
| **3. Delegate to subagent** | ⚠️ optional via `TOOL_USE_HARD_BLOCK=1` (denies tool calls at 85% with a directive to checkpoint or delegate) | ✅ warns at `TOOL_USE_DELEGATE_AT` (default 15) | ✅ `tool-use-stats --lint` |

**Default behavior:** advisory only — pattern detection emits 💡 stderr nudges, the model adapts on the next turn (or in the next response).

**Opt-in enforcement:** set `TOOL_USE_HARD_BLOCK=1` in your shell env to make the PreToolUse hook return a `permissionDecision: deny` at 85% of soft target. Claude Code blocks the call and feeds the reason back to the model, which then must checkpoint or delegate. Use sparingly — denying mid-task can break in-flight work if the threshold is wrong for your workflow.

```bash
# Tune in ~/.zshrc (defaults shown):
export TOOL_USE_SOFT_TARGET=35     # warning thresholds: 70% (24), 85% (29)
export TOOL_USE_DELEGATE_AT=15     # turn count that triggers "delegate" nudge
export TOOL_USE_HARD_BLOCK=0       # set to 1 for opt-in deny at 85%
```

### Retrospective coaching: `tool-use-stats --lint`

Scans `history.jsonl` and reports rule-1/2/3 violations from past turns, with an estimated slot-waste figure:

```
Lint findings — last 7 days
  Rule 1 — Batch parallel candidates: 3 turns
  Rule 2 — Chain candidates: 5 turns
  Rule 3 — Delegate candidates: 1 turn
  Estimated slot waste: ~25 main-session tool slots
  (i.e., that many calls could have been collapsed via batching/chaining/delegation)
```

Run weekly. If slot-waste is climbing, the model is drifting from the rules — tighten `TOOL_USE_SOFT_TARGET` or enable `TOOL_USE_HARD_BLOCK`.

### What we explicitly will NOT automate

- **Auto-merging** of sequential calls. Impossible without rewriting model output, which would break the protocol.
- **Auto-spawning** subagents. The hook can't generate subagent invocations on the model's behalf — that has to come from the model itself.
- **Pattern-matching on Bash command content** to guess "chainability." Too brittle; false positives would erode trust in the warnings.

## Soft vs. hard target

| Target | Value | Source |
|---|---|---|
| Soft (advisory) | 35 | This kit's default. Configurable via `TOOL_USE_SOFT_TARGET` env var. |
| Hard (enforced) | ~50 | Claude Code system bound. Undocumented. May change between versions. |

Hooks emit one-shot stderr warnings at 70% and 85% of the soft target. The 85% warning is the moment to checkpoint, batch, or delegate — not 1 call before the hard cap.

## Wiring

Hooks are registered automatically by `setup.sh`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "*",
      "hooks": [{"type":"command","command":"~/.claude/hooks/tool-use-counter.sh"}]
    }],
    "Stop": [{
      "hooks": [{"type":"command","command":"~/.claude/hooks/tool-use-reset.sh"}]
    }]
  }
}
```

`verify.sh` confirms hooks are present, executable, and registered.

## When to override the soft target

- **Lower** to 25 if you frequently hand off to subagents and want stronger nudges to delegate earlier.
- **Raise** to 45 only if you've measured your own turn distribution and confirmed you almost never hit 50 — and you accept the risk that the next Claude Code release tightens the hard cap.

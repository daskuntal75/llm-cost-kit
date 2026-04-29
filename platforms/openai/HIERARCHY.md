# OpenAI Hierarchy Adaptation

ChatGPT and OpenAI have a different layer structure than Claude. Here's how the 7-layer model maps.

## OpenAI's available layers

| Layer | OpenAI equivalent | Loads | Cost profile |
|---|---|---|---|
| L4 (account-wide) | Settings → Personalization → Custom Instructions | Every conversation | Compact, set once |
| L7 (per-project) | Project instructions (in Projects feature) | Per session in that project | Cached |
| L6 (skills) | Custom GPT system prompt | Per Custom GPT invocation | Pay-per-use |
| L1/L2 (Cowork) | n/a | n/a | n/a |
| L3 (Code) | n/a — use API system prompt for Codex/Cursor analogs | Per API call | Cached |

## Recommendations

### L4 — Custom Instructions (always-on)
Paste `core/OUTPUT_RULES.md` into Settings → Personalization → Custom Instructions. Most efficient layer.

### L7 — Project Instructions
In Projects, paste a lean per-project context (50-200 words). Don't re-state universal rules already in L4.

### L6 — Custom GPTs
Build separate Custom GPTs for distinct workflows (e.g., "Cost-optimized Coding GPT", "Cost-optimized Writing GPT") with their own system prompts encoding the routing rules from `platforms/openai/SYSTEM_PROMPT.md`.

## Reasoning effort control (o-series, GPT-5)

For reasoning models, set `reasoning_effort` parameter explicitly in API calls or Custom GPT settings:

| Task | Effort |
|---|---|
| Classification, extraction, formatting | `minimal` |
| Chat, drafting, summarization | `low` |
| Code, analysis, planning | `medium` |
| Research, complex multi-step | `high` |

Default to `low` or `medium`. Reserve `high` for explicitly hard problems.

## What NOT to put in L4

- Project-specific rules (those go in L7 or Custom GPT)
- Long context (eats your daily prompt budget)
- One-time directives (use a one-shot prompt instead)

## Memory pattern

OpenAI has built-in memory at the account level. Don't fight it — work with it. When locking a decision, use the explicit phrasing: "Remember this for future chats: [decision]". OpenAI's memory system will store it.

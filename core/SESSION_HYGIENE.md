# Session Hygiene

Context management is the largest cost lever most users ignore. Threads don't get cheaper the longer they run — they get more expensive with every turn because every prior message replays.

## The four rules

### 1. New topic = new session
Switching domains (code → strategy, personal → work) means starting a fresh chat. Cached context from old topic is pure waste in the new one.

### 2. Summarize before dropping a thread
Before closing a long session you might return to:

> Summarize this thread in 150 words: key decisions made, constraints established, open questions, and the single most important next step. Preserve any code snippets or structured data as-is. Omit pleasantries and chain-of-thought.

Save the summary. Next session, paste it as your first message.

### 3. Idle timer matters
Most LLMs cache prompt prefixes for ~5 minutes. Returning to an idle session means full reprocessing — fresh session cost plus full conversation history. If away more than 5 minutes, start fresh with a summary.

### 4. Batch, don't drip
Five related code edits in one prompt costs roughly one prompt's context overhead. Five separate prompts cost five times that overhead. Plan first, send once.

## Turn counter heuristic

| Turn count | Action |
|---|---|
| 1–11 | Normal |
| 12 | Consider summarizing soon |
| 15+ | Summarize now, fresh session next |

## What NOT to do

- Don't resume 3-day-old threads. Summarize what you need and start fresh.
- Don't paste an entire file when you need a 20-line section. Scope the context.
- Don't load every available tool/MCP server "just in case" — each adds overhead.
- Don't ask "can you also..." after task completion. Start fresh for non-trivial follow-ups.

## Memory pattern (Claude Cowork specific)

When you lock a decision, the memory-first skill emits a `Saving to Memory: <Type> — <n> — <Why> — <How to apply>` line that Cowork stores natively in its Memory panel. This means you don't have to manually remind Claude what was decided in future sessions — the Memory panel auto-injects.

This depends on the L2 Cowork Global Instructions explicitly directing the skill to use this format. See `HIERARCHY.md` for why L2 controls skill format directives, not the skill body.

## Status rollup pattern

When you ask "what's next" or "where are we", the status-rollup skill returns a Yesterday / Today / Blocked / CI / Cost format grounded in current state, not chat history. Always reads from native Memory panel + linked folders, never re-derives from compacted context.


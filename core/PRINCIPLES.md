# Core Principles — Universal Token Efficiency
# ─────────────────────────────────────────────────────────────────────────────
# These principles apply to every LLM platform: Claude, ChatGPT, Gemini,
# and anything that comes after. Platform-specific tactics live in
# platforms/<name>/ — these fundamentals do not change.
# ─────────────────────────────────────────────────────────────────────────────

## Why Tokens Cost Money (and What Actually Wastes Them)

Every token in a large language model request is billed twice: once as input
(what you send), once as output (what the model returns). The input side compounds
silently — every message in a multi-turn thread re-sends the full conversation history.
Most waste accumulates there, not in the length of individual answers.

**The six compounding waste sources, ranked by impact:**

| Source | Typical waste | Fix |
|---|---|---|
| Loaded tools/plugins you aren't using | ~18K tokens per unused server, per message | Load per-context, not globally |
| Re-processing cold context | Full history cost with no cache benefit | Clear and restart with a 150-word summary |
| Accumulated thread history past turn 15 | Grows quadratically | Summarize and reset |
| Opener/closer/restatement tokens | 20–50 tokens per response, every response | System prompt / user preferences |
| Sub-agents receiving full history | Full cost × number of agents | Scoped JSON brief only |
| Top-tier model for routine tasks | 5–20× cost vs small model | Route by task complexity |


## Principle 1 — Information Density Over Brevity

The goal is not short responses. The goal is responses where every token carries
signal. A 400-token answer that's complete beats a 200-token answer that requires
a follow-up, because follow-ups re-send the whole thread.

**Implication:** Token budgets (defined in config.yaml) are upper bounds, not targets.
If the correct answer is 50 tokens, 50 tokens is right.


## Principle 2 — Context Is Expensive At Rest

The prompt cache is the single most powerful cost lever in Claude (and increasingly
in OpenAI and Gemini as well). Cache hits are cheap. Cache misses are full price.

Rules that follow from this:
- An active session costs much less than a resumed one after idle time
- Summarize before switching topics, not after
- The smaller the context you carry into a new session, the cheaper every subsequent turn
- Structured summaries (150 words, fixed schema) are cheaper than re-explaining freeform


## Principle 3 — Match Model to Task

Most tasks do not require the best model. The escalation hierarchy exists for a reason:

```
Simple transform / classification / formatting
  → Cheapest small model (Haiku / GPT-4o-mini / Gemini Flash 8B)

Analysis / strategy / multi-turn work
  → Mid-tier model (Sonnet / GPT-4o / Gemini 2.0 Flash)

Hard reasoning / very long context / provably failing on mid-tier
  → Top-tier only (Opus / o3 / Gemini 2.5 Pro)
  → Requires: 2 failures on same task, same session
```

Auto-escalation (upgrading model because a task feels important) is one of the
most common and most expensive habits. Importance is not the same as complexity.


## Principle 4 — Tools Are Not Free

Every tool definition loaded into the context — whether an MCP server, a ChatGPT plugin,
a Gemini extension, or a function definition in the API — adds its full schema to every
input message. This overhead is constant per message, not per use.

**Rule:** Load only the tools the current task will actually call.
Use context-specific configurations (the `platforms/<name>/` configs) to enforce this.


## Principle 5 — Sub-Agents Need Minimum Viable Context

Orchestrator → sub-agent communication is where context cost can multiply unboundedly.
A 10-turn conversation passed to 5 parallel sub-agents costs 50× the thread.

**The scoped brief pattern (works on every platform):**
```json
{
  "task": "one sentence",
  "constraints": ["list of hard requirements"],
  "inputs": { "only what this agent needs to complete its task" },
  "output_format": "what to return and in what structure",
  "context": "2-3 sentences of background — nothing more"
}
```
The orchestrator maintains full state. Sub-agents are stateless workers.


## Principle 6 — Thread Hygiene Is Maintenance, Not Cleanup

Letting a thread run to 30 turns before summarizing is like letting technical debt
accumulate — the cleanup cost is higher than the cost of doing it continuously.

**The 12/15 rule (universal):**
- Turn 12: notice that the thread is getting long
- Turn 15: summarize and reset, no exceptions

**The 150-word summary protocol:**
```
Summarize this thread in 150 words: key decisions made, constraints established,
open questions, and the single most important next step. Preserve any code
snippets or structured data as-is. Omit pleasantries and chain-of-thought.
```
Paste in current thread → copy output → new chat → paste as first message.


## Principle 7 — Output Discipline Saves Tokens on Every Response, Forever

User preferences and system prompts that enforce output discipline are the highest
ROI investment in this toolkit. Set them once, they apply to every conversation.

**The five rules (paste into any LLM's system/preferences):**
1. Lead with the answer, not the reasoning
2. No openers (Great!, Sure!, Certainly!)
3. No closers (Let me know if you need anything!)
4. Tables over prose for comparisons
5. One recommendation, not a menu of options

These five rules eliminate 20–60 tokens of pure overhead from every response.
At 10 responses per session and 200 sessions per year, that's millions of saved tokens.


## Principle 8 — Measure, Then Optimize

Token optimization without visibility is guessing. Every platform has usage reporting.
Review it on the first of each month:
- Which model drove the most cost?
- Which session type (quick / deep work / build) was most expensive?
- Was any Opus/o3/Gemini Pro usage actually justified?

The answers tell you where to tighten next.

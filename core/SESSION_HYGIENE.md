# Session Hygiene — Universal Thread Management Protocol
# ─────────────────────────────────────────────────────────────────────────────
# These protocols work on any LLM platform. Platform-specific mechanics
# (like Claude's /compact and /clear commands) are noted where relevant,
# but the underlying discipline is the same everywhere.
# ─────────────────────────────────────────────────────────────────────────────


## The Core Problem

Every message in a multi-turn thread re-sends the full conversation history as
input tokens. A 15-turn thread means every response processes turns 1–14 again.
By turn 20, you are paying for 19 turns of context on every single exchange.

This is not a bug — it's how transformers work. The fix is thread hygiene.


## The 12/15 Rule

**Turn 12:** Notice. The thread is getting expensive. Consider whether the current
topic warrants continuing or whether a summary + fresh start would be cleaner.

**Turn 15:** Act. No exceptions. Run the summarization protocol below, start a new
chat with the summary as your first message.

The skill/system prompt auto-appends a reminder at these turns if installed.


## The 150-Word Summary Protocol

Use this prompt in the current thread before starting a new one:

```
Summarize this thread in 150 words: key decisions made, constraints established,
open questions, and the single most important next step. Preserve any code
snippets or structured data as-is. Omit pleasantries and chain-of-thought.
```

Copy the output. Open a new chat. Paste the summary as your first message.
Then continue from where you left off — with 95% less context overhead.

**Why 150 words?** It's enough to preserve decisions and constraints without
re-inflating the context. At ~200 tokens, it costs almost nothing per turn.


## Platform-Specific Session Commands

### Claude (Claude Code)

| Situation | Command | Why |
|---|---|---|
| Session active, last message < 5 min | `/compact` | Cache is warm — compacting is cheap |
| Session idle > 5 min | `/clear` | Cache is cold — `/compact` re-processes at full price |
| After `/compact` | `/rename [task-name]` | Saves the session for `/resume` |
| Custom compact focus | `/compact Focus on function signatures, API contracts, open TODOs` | Preserves the most useful residue |

**The 5-minute rule:** Prompt cache TTL on Claude is approximately 5 minutes for
Sonnet. After that window, the cache is cold and `/compact` costs the same as
re-processing from scratch. Use `/clear` instead — it's free, and you bring
only the 150-word summary forward.

### ChatGPT

No native `/compact` or `/clear` commands. Thread management is manual:
- Use the 150-word summary protocol at turn 15
- Start a new chat — ChatGPT does not cache within a conversation the same way
- Memory: ChatGPT's built-in memory stores persistent facts across sessions
  (equivalent to Claude's memory system). Keep it scoped to truly persistent facts.
- Temporary chat: Use for one-off tasks where you don't want memory pollution

### Gemini

No native compaction commands. Thread management is manual:
- Use the 150-word summary protocol at turn 15
- Gemini 2.0 Flash and 2.5 Pro have very long context windows (1M+ tokens)
  which can be tempting to abuse — long context does not mean free context
- Gems maintain their own context per conversation; switching Gems resets context
- Google AI Studio: "Reset" conversation button clears thread manually


## Tool Loading Hygiene

Tools/plugins/MCP servers loaded into a session contribute to input token cost
on every message, even if never called.

| Platform | How to control tool loading |
|---|---|
| Claude Code | Use aliased launchers: `claude-saas`, `claude-work`, `claude-infra`, `claude-x` |
| Claude Code (in-session) | `/mcp` → disable unused servers mid-session |
| ChatGPT | Disable unused capabilities in the Custom GPT builder or per-session |
| ChatGPT API | Pass only the `tools` array entries actually needed for the task |
| Gemini | Disable Workspace extensions not needed for the current Gem/session |
| Gemini API | Pass only the `tools` / `function_declarations` the task requires |

**Rule of thumb:** ~18K tokens overhead per loaded tool, per message. A session
with 3 unnecessary tools loaded runs at 54K extra input tokens per exchange.


## Context Handoff Format

When handing context between sessions (or to a sub-agent), use this structure.
It maximizes information density and minimizes token cost.

```
CONTEXT HANDOFF — [Date] [Project Name]

DECISIONS MADE:
- [Decision 1]
- [Decision 2]

CONSTRAINTS ESTABLISHED:
- [Constraint 1]
- [Constraint 2]

CURRENT STATE:
[2-3 sentences describing where things stand]

OPEN QUESTIONS:
- [Question 1]
- [Question 2]

NEXT STEP:
[Single most important action]

ARTIFACTS:
[Any code snippets, configs, or structured data — preserved as-is]
```

This format works as:
- The first message in a new thread (session reset handoff)
- The context field in a sub-agent brief
- A project status note in Claude Projects / ChatGPT Projects / Gems


## Monthly Hygiene Review

On the 1st of each month, check your LLM usage dashboard:

| Question | What to look for |
|---|---|
| Which model drove most cost? | Was top-tier model use justified? |
| Which session type was most expensive? | Build sessions with many agentic calls? |
| Any suspiciously long threads? | Threads that should have been reset at turn 15 |
| Tool usage breakdown | Are loaded tools actually being called? |
| Credit/balance trend | Are you on track for the month? |

Adjustments to make after the review:
- Tighten model routing if top-tier model was overused
- Add tool configs for any new contexts that emerged
- Update CLAUDE.md / SYSTEM_PROMPT.md / GEM_INSTRUCTIONS.md if project context changed

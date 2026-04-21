# OpenAI Adapter — llm-cost-kit

Cost optimization for ChatGPT, Custom GPTs, and the OpenAI API.

## Files

| File | Purpose |
|---|---|
| `SYSTEM_PROMPT.md` | Drop-in system prompt for ChatGPT Projects, Custom GPTs, or API `system` messages |

## Concept Mapping — Claude → OpenAI

| Claude concept | OpenAI equivalent |
|---|---|
| `CLAUDE.md` | Custom GPT system prompt / ChatGPT Project instructions |
| Claude Projects | ChatGPT Projects |
| Cowork Skills | Custom GPTs with pre-set system prompts |
| MCP servers | ChatGPT plugins / Custom GPT Actions / API `tools` array |
| `/compact` | No equivalent — use the 150-word summary protocol manually |
| `/clear` | Start a new chat |
| `claude-saas` alias | API calls with scoped `tools` array per context |
| Memory (Claude) | ChatGPT built-in memory (Settings → Personalization) |
| ccusage | platform.openai.com/usage |
| Haiku (sub-tasks) | gpt-4o-mini |
| Sonnet (default) | gpt-4o |
| Opus (escalate) | o1 / o3 (use very sparingly — reasoning tokens are expensive) |

## Quick Setup

1. Copy the system prompt from `SYSTEM_PROMPT.md`
2. Replace all `[BRACKET]` placeholders with your actual context
3. Paste into ChatGPT Projects (for Chat use) or Custom GPT builder (for reusable agents)
4. Set Custom Instructions in Settings → Personalization for global preferences
5. Set a monthly spend limit at platform.openai.com → Settings → Limits

## Key Differences vs Claude

**No cache window rule:** OpenAI's prompt caching is managed automatically (API tier).
In ChatGPT UI, there's no `/compact` equivalent — manual summarize + new chat is the
only tool.

**Reasoning model cost:** o1/o3 charge for internal reasoning tokens invisible in the
output. A single hard reasoning task on o3 can cost as much as 50+ gpt-4o calls.
The escalate threshold is strict: **2 failures on the same task, same session.**

**Memory scope:** ChatGPT memory persists across all conversations unless scoped.
Claude's memory is more session-aware. Prune ChatGPT memory monthly to prevent
stale context from leaking into unrelated sessions.

# Gemini Adapter — llm-cost-kit

Cost optimization for Gemini Advanced, Gems, and the Google Gemini API.

## Files

| File | Purpose |
|---|---|
| `GEM_INSTRUCTIONS.md` | Drop-in system instructions for Gems, Google AI Studio, and Gemini API |

## Concept Mapping — Claude → Gemini

| Claude concept | Gemini equivalent |
|---|---|
| `CLAUDE.md` | Gem system instructions / AI Studio system prompt |
| Claude Projects | Gems (each Gem = a persistent, context-specific assistant) |
| Cowork Skills | Gems with pre-set system instructions |
| MCP servers | Gemini Extensions (Workspace: Gmail, Calendar, Drive, Docs) |
| `/compact` | No equivalent — use the 150-word summary protocol manually |
| `/clear` | Start a new Gem conversation |
| `claude-saas` alias | Different Gem per context (Gems are the natural scoping unit) |
| Memory (Claude) | Gemini Gems maintain per-conversation history; no cross-session memory by default |
| ccusage | console.cloud.google.com → APIs → Gemini API usage |
| Haiku (sub-tasks) | gemini-1.5-flash-8b |
| Sonnet (default) | gemini-2.0-flash |
| Opus (escalate) | gemini-2.5-pro |

## Quick Setup

1. Copy the system instructions from `GEM_INSTRUCTIONS.md`
2. Replace all `[BRACKET]` placeholders with your actual context
3. Create one Gem per context area (Work, SaaS, Infra, General)
4. Enable only the Google Workspace extensions each Gem needs
5. Set billing alerts at console.cloud.google.com if using the API

## Key Differences vs Claude

**Context window temptation:** Gemini 2.5 Pro supports 1M+ token context.
This is powerful but not free on the API. Long context ≠ cheap context.
Apply the same summarization and reset discipline regardless of window size.

**Gem-native scoping:** Unlike Claude where Projects are a UI layer on top of
the same model, Gemini Gems are natively designed as the scoping mechanism.
Create a Gem for each context rather than manually loading different configs.

**Workspace integration:** Gemini's native integration with Gmail, Calendar,
Drive, and Docs is tighter than Claude's MCP equivalents. But the same rule applies:
disable extensions not needed for the current Gem's purpose.

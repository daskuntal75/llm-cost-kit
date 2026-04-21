# Claude Adapter — llm-cost-kit

Cost optimization for Claude Chat, Claude Code, and Cowork.
This adapter contains everything from the original `claude-cost-kit`.

## Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Drop into project root — governs Claude Code sessions |
| `SKILL.md` | Install via Cowork → Skills — auto-detectors + turn nudges |
| `mcp-configs/` | 4 context-scoped MCP server configurations |

## Shell Aliases (added by `setup.sh`)

| Alias | MCP servers loaded | Use for |
|---|---|---|
| `claude-saas` | Supabase + Stripe + GitHub | SaaS / app development |
| `claude-work` | Google Calendar + Gmail | Work tasks and scheduling |
| `claude-infra` | GitHub only | AI infrastructure, agent projects |
| `claude-x` | None | Lean default, quick lookups |
| `cu` | — | `ccusage` token report |
| `cu-today` | — | Today's token usage |
| `agent-brief` | — | Copies sub-agent JSON template to clipboard |

## Concept Mapping — Claude is the Reference Platform

| Claude concept | OpenAI equivalent | Gemini equivalent |
|---|---|---|
| `CLAUDE.md` | Custom GPT system prompt | Gem system instructions |
| Claude Projects | ChatGPT Projects | Gems |
| MCP servers | ChatGPT plugins / API `tools` | Gemini Extensions |
| `/compact` | Manual summarize + new chat | Manual summarize + new chat |
| `/clear` | Start new chat | Start new Gem conversation |
| ccusage | platform.openai.com/usage | console.cloud.google.com/apis |
| Haiku | gpt-4o-mini | gemini-1.5-flash-8b |
| Sonnet | gpt-4o | gemini-2.0-flash |
| Opus | o1 / o3 | gemini-2.5-pro |
| Cowork Skills | Custom GPTs | Gems with system instructions |

## Quick Setup

```bash
bash platforms/claude/setup.sh
source ~/.zshrc
```

See the top-level `setup.sh` for the unified wizard that handles all platforms.

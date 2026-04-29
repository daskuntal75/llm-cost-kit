# LLM Cost Kit

> 40-70% cost reduction for Claude, ChatGPT, and Gemini — without quality loss.

A complete, layered architecture for managing instructions across all surfaces of an LLM workflow.

## Download

Pick the kit for your platform from [Releases](https://github.com/daskuntal75/llm-cost-kit/releases/latest):

| Kit | For |
|---|---|
| `claude-cost-kit.zip` | Claude.ai, Claude Code, Cowork users |
| `openai-cost-kit.zip` | ChatGPT, Custom GPTs, OpenAI API |
| `gemini-cost-kit.zip` | Gemini, Gem builder, AI Studio |
| `llm-cost-kit.zip` | All three platforms in one bundle |

## The 7-layer hierarchy

The most important concept in this kit. Where you put your instructions matters as much as what they say.

![Hierarchy diagram](diagrams/hierarchy-diagram.png)

## Decision tree — where should this rule go?

For any new instruction, walk this tree to find the right layer.

![Decision tree](diagrams/decision-tree-diagram.png)

## Quick start

```bash
unzip claude-cost-kit.zip
cd claude-cost-kit
bash setup.sh
```

Then follow the manual UI steps the script lists at the end.

See [`core/HIERARCHY.md`](core/HIERARCHY.md) for the full layer guide.

## What's new in v3.4 (latest)

- **Subscription-aware cost tracking** — drops the broken soft/hard cap framework that was wrong for Pro/Max plan users
- **Two-signal cost model** — subscription value ratio (ccusage retail-equivalent ÷ plan fee) + API pool burn
- **Throttle event tracking** — empirical signal for plan right-sizing since Anthropic doesn't expose throttle thresholds
- **Monthly review CLI** — `update-claude-cost --monthly-review` outputs decision aid
- **Plan-tier downgrade test workflow** — `update-claude-cost --tier-test <smaller-plan>`

v1.0 (April 24) is preserved at the [v1.0 release](https://github.com/daskuntal75/llm-cost-kit/releases/tag/v1.0) for historical reference.

## What you'll save

Real-world numbers from heavy-usage measurement on Claude Max plan:

| Metric | Before | After | Win |
|---|---|---|---|
| Cowork skills loaded per turn | 185 | ~36 | -7,500 tokens/turn |
| L1 project instructions per-turn | ~4,000 tokens | ~130 tokens | -97% |
| Per-turn cost (Sonnet 4.6 / Medium) | $0.04 | $0.005 | -88% |

## Enhancement requests for Anthropic

Two opportunities (and an offer) documented at [Anthropic-Enhancement-Requests.md](Anthropic-Enhancement-Requests.md):

1. Subscription throttle threshold transparency — expose a "% of monthly quota used" signal
2. Document the instruction hierarchy formally on docs.anthropic.com
3. Hire me to work on Anthropic's customer experience

## License

Apache 2.0 — free to use, modify, share.

## Issues + contributions

Open issues at https://github.com/daskuntal75/llm-cost-kit/issues. PRs welcome.

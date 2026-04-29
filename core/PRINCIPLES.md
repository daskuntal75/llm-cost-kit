# Core Principles

Three principles drive all LLM cost optimization. Platform-specific tactics flow from these.

## 1. Every token must earn its place

Tokens cost money on input AND output. Agentic loops compound — thinking tokens, tool calls, tool results, and final output all bill the same way. Budget at the loop level, not per-call.

## 2. Route by task complexity

The cheapest model that produces required quality is the right model. Default to the smaller model. Escalate deliberately, not reflexively.

| Task | Right-sized model |
|---|---|
| Lookup, classification, summarization | Smallest tier |
| Drafting, conversation, synthesis | Mid tier |
| Strategic reasoning, complex code | Top tier |
| Autonomous agents, multi-hour runs | Top tier + high effort |

## 3. Discipline beats features

A clean prompt to a mid-tier model beats a sloppy prompt to the flagship. Output caps, context hygiene, and session boundaries save more money than model switches.

## Implementation: layered architecture

Where you put your instructions matters as much as what they say. See `HIERARCHY.md` for the 7-layer model that determines per-turn vs per-session vs lazy-loaded cost.


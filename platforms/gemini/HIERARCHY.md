# Gemini Hierarchy Adaptation

Gemini's structure is closer to OpenAI's than Claude's. Here's the layer mapping.

## Gemini's available layers

| Layer | Gemini equivalent | Loads | Cost profile |
|---|---|---|---|
| L4 (account-wide) | Personal context in Gemini app | Every conversation | Compact |
| L6 (Gems) | Gem builder system instructions | Per Gem invocation | Pay-per-use |
| L3 (API/Studio) | AI Studio system instructions | Per session | Cached |
| L1/L2 (Cowork) | n/a | n/a | n/a |
| L7 (per-project) | n/a | n/a | n/a |

Gemini has fewer layered surfaces than Claude. Compensate with focused Gems.

## Recommendations

### L4 — Personal context
In Gemini app: Settings → Personal Context. Paste `core/OUTPUT_RULES.md`. Universal across all chats.

### L6 — Gems for distinct workflows
Build a Gem per workflow ("Cost-Optimized Coder", "Cost-Optimized Writer", etc.) with the system instructions in `platforms/gemini/GEM_INSTRUCTIONS.md` plus your domain context.

### L3 — AI Studio
For API/Studio work, paste GEM_INSTRUCTIONS.md as the system instruction. Cached per session.

## Thinking budget control (Gemini 2.5+)

Gemini 2.5 uses `thinking_budget` to cap reasoning tokens:

| Task | thinking_budget | Model |
|---|---|---|
| Extraction, classification | 0 or `disabled` | Flash |
| Chat, drafting | 256 | Flash |
| Analysis, code | 1024 | Pro |
| Complex multi-step | 2048–4096 | Pro |

Flash is your daily driver. Escalate to Pro deliberately.

## Long-context discipline

Gemini's 1M-2M context is a tool, not a pattern. Don't dump everything — filter first:
- Only include files relevant to the current task
- Summarize prior conversation before continuing long threads
- For code review, paste the specific diff, not the entire file

## Grounding

- Use Google Search grounding only when currency matters (latest news, prices, recent events)
- Don't ground general-knowledge questions — adds latency and cost with no benefit

## What Gemini lacks (vs Claude)

- No per-project context layer (compensate with Gems)
- No native Memory panel (compensate with explicit "Remember:" lines in Personal Context)
- No Cowork-style global instructions (one Personal Context per account)

For users running multi-platform setups, treat Gemini as a "Flash-default for cheap drafting / Pro for hard analysis" workhorse. Don't try to recreate Cowork's layer architecture inside Gemini.

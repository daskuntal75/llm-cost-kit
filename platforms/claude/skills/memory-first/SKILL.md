---
name: memory-first
description: Persists locked-in decisions, corrections, and non-obvious confirmations to Cowork's native Memory panel at the moment they are made — not later. Use whenever the user locks a decision ("yes do that", "let's go with X"), corrects an approach you just took, confirms a non-obvious choice, references prior conversation context ("like we discussed", "the v2 plan"), or asks "what did we decide about". Also triggers when about to recommend something that prior decisions might override (tool choice, model choice, scope decision).
version: 1.1
updated: 2026-04-27
depends_on: cost-optimizer (uses its cost tally format)
feeds: status-rollup (provides the memory it reads from)
---

# Memory-First Context Skill — v1.1

## What v1.1 changes from v1.0
- Switched output format from `📌 MEMORY NOTE` block (old) to Cowork-native `Saving to Memory:` single-line syntax
- The `Saving to Memory:` line is consumed by Cowork's native Memory panel automatically
- No more user copy/paste — Cowork stores the memory natively
- Works seamlessly with Cowork's "Memory" right-panel UI

## When to fire

Trigger on linguistic cues:
- User locks a decision: "yes do that", "let's go with X", "we should use Y"
- User corrects an approach: "no, actually...", "instead of that..."
- User confirms a non-obvious choice: "yes that's right" (when YOU asked confirmation)
- User references prior context: "like we discussed", "the v2 plan", "what we decided"
- User asks: "what did we decide about X"
- About to recommend something a prior decision might override (always check memory first)

## Output format (Cowork — v1.1)

Emit a single line BEFORE main response content:

```
Saving to Memory: <Type> — <Name> — <Why> — <How to apply>
```

Where:
- `Type` is one of: `feedback`, `project`, `user`, `reference`
- `Name` is a short title (5-10 words)
- `Why` is the rationale in 1 sentence (so future-you knows the edge cases)
- `How to apply` is actionable guidance in 1 sentence (so the rule isn't theoretical)

Then continue with the main response.

## Output format (Chat — fallback)

In Chat (no native Memory panel), emit:

```
📌 MEMORY NOTE
Type: <type>
Name: <n>
Why: <rationale>
How to apply: <guidance>
```

Then continue.

## The 4 memory types

| Type | Purpose | Trigger |
|---|---|---|
| `user_*` | Who the user is + how they work | Any new detail about role, stack, expertise, preferences |
| `feedback_*` | Rules the user gave about how to work | Correction OR non-obvious confirmation |
| `project_*` | State/scope/progress of ongoing work | Who's doing what, why, by when |
| `reference_*` | Pointers to external systems | "Bugs live in Linear X", "Dashboard at grafana.internal/Y" |

## What NOT to save

- Code patterns, file paths, architecture — derivable by reading the repo
- Git history, recent changes — `git log` is authoritative
- Debugging recipes — fix is in code, commit message has context
- In-progress task state — use plans or todos, not memory

Even if the user asks to save a "PR list" or "activity summary" — push back and ask what was *surprising* or *non-obvious*. That's the part worth keeping.

## When to READ memory

- User references prior-conversation work ("like we discussed", "the v2 plan")
- User asks "what's next" / "what's open" / "where are we" → delegate to status-rollup
- About to recommend something memory might override (tool choice, model choice)
- Always verify before acting: memory is a claim about a moment in time, not eternal truth

## Updating + pruning

- When user marks something done ("shipped", "merged"), update relevant `project_*` in same turn
- When a decision is overridden, add the override in-place with date + rationale
- When a memory becomes wrong, remove it — stale memory is worse than no memory

## Critical architecture note

**Cowork only loads skill *descriptions*, not full SKILL.md bodies.** That means the `Saving to Memory:` format directive must ALSO be embedded in your L2 Cowork Global Instructions for it to actually fire. See HIERARCHY.md for the full picture.

## Cost tally rule
End every response with the cost tally per cost-optimizer skill (always-on).

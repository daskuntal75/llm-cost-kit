---
name: cost-optimizer
description: >
  Actively manages token cost and context efficiency across Claude Chat, Claude Code, and Cowork
  without compromising output quality. Use this skill whenever the user mentions cost, credits,
  tokens, budget, "getting expensive", or starts a session involving heavy multi-turn work,
  complex agentic tasks, or large codebases. Also triggers automatically at the start of any
  session involving sub-agents, multi-step workflows, or large file processing.
  This skill enforces lean context hygiene, smart model routing, output compression,
  and sub-agent scoping rules so every token is earned.
---

# Cost Optimizer Skill

**Goal:** 40–70% token reduction with zero quality loss across all Claude surfaces.

## On Activation

When this skill triggers, immediately:
1. Identify the surface (Chat / Code / Cowork)
2. Check session type (quick lookup | multi-turn deep work | agentic task | build)
3. Apply the matching profile from the table below
4. Confirm routing with one line: `[Cost-Opt: {profile} | model: {model} | max output: {limit}]`

## Session Profiles

| Profile | Trigger condition | Model | Max output |
|---|---|---|---|
| **Quick** | Single Q&A, fact lookup, short draft | Sonnet | 300 tokens |
| **Deep Work** | Multi-turn analysis, strategy, research | Sonnet | 800 tokens |
| **Build** | Code gen, agentic task, multi-file edits | Sonnet (Haiku for sub-tasks) | 1200 tokens |
| **Research** | Web search + synthesis | Sonnet | 600 tokens |
| **Escalate** | Only when Sonnet output is provably insufficient | Opus | 1000 tokens |

Never auto-escalate to Opus. User must explicitly request it or output must have failed twice.

## Context Hygiene Rules (all surfaces)

### Turn Counter Nudge (automatic, every response)
Claude must silently count human turns in the current conversation. A "turn" = one human message.

**At turn 12:** Append this line at the very end of the response, after all content:
```
⚠️ [Turn 12 — consider summarizing this thread soon before context grows further]
```

**At turn 15+:** Append this block at the very end of every subsequent response:
```
⚠️ [Turn {N} — thread is long. To save tokens and preserve quality, summarize now:
Copy this prompt → start a new chat → paste as your first message:

"Summarize this thread in 150 words: key decisions made, constraints established,
open questions, and the single most important next step. Preserve any code snippets
or structured data as-is. Omit pleasantries and chain-of-thought."]
```

Replace `{N}` with the actual turn number. Never interrupt mid-response.

### Thread Summarization Trigger
Summarize and reset when ANY of these fire:
- Topic shifts from one domain to another
- Thread exceeds 15 turns OR 30 minutes elapsed
- User says "new task", "different topic", "let's switch to..."

**Summarization prompt:**
```
Summarize this thread in 150 words: key decisions made, constraints established,
open questions, and the single most important next step. Preserve any code snippets
or structured data as-is. Omit pleasantries and chain-of-thought.
```
Start a fresh chat with only that summary as context.

### Output Compression Rules
Always apply unless user explicitly asks for more:
- Lead with the answer, not the reasoning
- Tables over prose for comparisons
- No restating the question
- No closing pleasantries
- No opener phrases ("Great!", "Certainly!", "Of course!")
- Code blocks: complete and runnable, no truncation
- If response would exceed profile max → ask: "Want the full version or a condensed summary?"

## Inline Pattern Detection & Reminders

Scan every incoming message for these patterns. Append the matching reminder at the END of the response — after all content. At most 2 reminders per response.

### Pattern 1 — Idle session → /clear reminder
**Triggers on:** "picking up where we left off", "back to this", "continuing from earlier", "as we discussed", "from our last session", "returning to", "it's been a while"

```
💡 [Idle session detected — if your last Claude Code message was >5 min ago, use /clear
   instead of /compact. Cold cache = full reprocessing cost. Start fresh with a 2-sentence
   context summary in your first message.]
```

### Pattern 2 — Multi-file task → Plan mode reminder
**Triggers on:** 3+ file names in one message, "refactor", "update all", "across the codebase", "multiple files"

```
💡 [Multi-file task — press Shift+Tab (plan mode) before starting. Claude proposes the
   approach for approval before touching any files. Then batch ALL changes in ONE prompt.]
```

### Pattern 3 — Sequential edits → Batching reminder
**Triggers on:** "now do the same for", "apply this to", "also update", "next, update", "repeat this for"

```
💡 [Batching opportunity — combine related changes in one prompt instead of sequential
   messages (3x overhead). Format: "Update X in a.ts, b.ts, c.ts: - a.ts: [what] - b.ts: [what]"]
```

### Pattern 4 — Sub-agent / orchestration → Scoped brief reminder
**Triggers on:** "sub-agent", "spawn", "orchestrate", "multi-agent", "agent loop", "dispatch to"

```
💡 [Sub-agent task — scoped brief only, never full history. Type 'agent-brief' in Terminal
   to copy the JSON template to clipboard. Orchestrator holds full state; sub-agent gets minimum context.]
```

## Claude Code — Specific Rules

### Session Start Checklist
1. Is this a continuation or new task? → If new, `/clear` first
2. Are unnecessary MCP servers active? → `/mcp` → disable unused (each = ~18K tokens/msg)
3. Is CLAUDE.md in project root? → If not, add it
4. Is the task scoped? → File + line > function > module > codebase

### /compact Timing Rule
- Active session (last message < 5 min ago) → `/compact` to summarize within cache window
- Idle session (> 5 min) → `/clear` (cache is cold; compacting re-processes at full cost)
- Custom compact: `/compact Focus on function signatures, API contracts, and open TODOs`
- After compacting: `/rename [task-name]`

### Sub-Agent Scoping Rule
Never pass full conversation history to a sub-agent. Always use:
```json
{
  "task": "one-sentence description",
  "constraints": ["list of hard constraints"],
  "inputs": { "key": "minimum required data only" },
  "output_format": "expected return structure",
  "context": "2-3 sentences of background — no more"
}
```

### File Reference Discipline
- Specific beats broad: `@src/auth/middleware.ts:45` not `@src/`
- Batch related changes: one prompt for 3–5 related edits
- Use plan mode (Shift+Tab) before any task touching > 3 files

## Cowork — Specific Rules

### Project Isolation
Each major context = its own Project. Create separate projects for:
- Active product builds (SaaS, app, infra)
- Work/job search tasks
- Research and writing
- Personal/admin

Never run cross-context work in the same Project session. Context bleed is the #1 hidden cost.

### Skill Loading Rule
Load only skills relevant to the current task. Each loaded skill adds tokens to every message.
- Product/engineering work → load product + engineering skills only
- Writing/docs → load writing skills only
- Never load 3+ heavy skills simultaneously

### Connector Discipline
Disable connectors not needed for the session. Active connectors that aren't used still
contribute to tool listing overhead.

## Billing Guardrails

- Extra credits balance < $50 → pause before starting any agentic task
- Auto-reload: keep OFF — manual top-ups in bulk only
- Never trigger Opus for tasks that passed Sonnet previously in the same session
- If a task requires > 10 sequential tool calls → pause and ask if it should be split

## Quality Safeguards

Cost efficiency never overrides:
1. **Correctness** — if a shorter output would be wrong, give the correct longer one
2. **Code completeness** — always produce runnable, complete code blocks
3. **Security** — never skip security checks to save tokens
4. **Structured deliverables** — documents, analyses, plans always get full treatment

## Quick Reference Card

| Situation | Action |
|---|---|
| New chat, same topic | Continue — context carries |
| New chat, different topic | `/clear` or new thread + summary handoff |
| Thread at 15 turns | Summarize + reset |
| Sub-agent task | Pass scoped JSON brief only |
| MCP servers unused | `/mcp` → disable |
| 5+ related code edits | Batch in one prompt |
| Session idle > 5 min | `/clear` (cheaper than `/compact`) |
| Tempted to use Opus | Sonnet first — escalate only on second failure |
| Response getting long | Ask: condensed or full? |
| Monthly billing date | Check Usage page → review model breakdown |

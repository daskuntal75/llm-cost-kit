# Claude Code Config
# ─────────────────────────────────────────────────────────────────────────────
# Drop this file in the root of any project.
# Claude Code reads it automatically at session start.
# Edit the sections marked [CUSTOMIZE] with your actual context.
# ─────────────────────────────────────────────────────────────────────────────

## Identity  <!-- [CUSTOMIZE] Replace with your role and primary stack -->
[Your Role / Title] | [Domain focus e.g. "AI Security PM" or "Full-Stack Engineer"]
Primary stack: [e.g. GCP, Supabase, Next.js, Python, FastAPI]
Active project: [Your Project Name] — [one sentence description]

## Response Rules (always active)
- Answer first, explain after (if at all)
- Complete, runnable code only — no truncation, no TODO placeholders
- No preamble ("Great!", "Sure!", "Of course!")
- No restatement of the question
- Tables > prose for comparisons
- One recommendation, not a menu of options

## Output Limits by Task
| Task type | Max response |
|---|---|
| Quick lookup / single function | 300 tokens |
| Multi-file feature | 800 tokens |
| Architecture / security review | 600 tokens |
| Full component / API endpoint | 1200 tokens |

## File Reference Discipline
- Always reference specific files + line ranges when possible
- Batch 3–5 related edits in a single prompt
- Never "scan the whole codebase" — scope to the minimum necessary files

## Sub-Agent Rule
Pass scoped JSON briefs only. Never pass full conversation history to a sub-agent:
```json
{
  "task": "one-sentence description",
  "constraints": ["hard constraint 1", "hard constraint 2"],
  "inputs": { "key": "minimum required data only" },
  "output_format": "expected return structure",
  "context": "2-3 sentences of background — no more"
}
```

## Session Hygiene
- New unrelated task → /clear before starting
- Active session growing long → /compact (within 5 min of last message)
- Idle > 5 min → /clear is cheaper than /compact
- Custom compact: /compact Focus on function signatures, API contracts, open TODOs
- After /compact: /rename to save session before clearing

## MCP Server Policy
- Run /mcp at session start — disable servers not needed for current task
- Each active server adds ~18K tokens/message in tool listing overhead
- Only load servers the current task will actually call

## Security Rules  <!-- [CUSTOMIZE] Add your project's non-negotiable security rules -->
<!-- Example for a SaaS with auth and payments: -->
- [Your security rule 1, e.g. "Always scope DB queries with user ID — never bypass row-level security"]
- [Your security rule 2, e.g. "HMAC-sign all generated URLs — never produce unsigned links"]
- [Your security rule 3, e.g. "Validate all user-submitted content before passing to LLM"]

## Model Routing
- Default: Sonnet (latest)
- Sub-tasks (classification, formatting, simple transforms): Haiku (latest)
- Escalate to Opus only if Sonnet output fails twice for the same task
- Never auto-escalate

## Tone
Direct. No hedging. If something is wrong, say so. If a better approach exists, flag it once.

# Gemini Gem Instructions — Cost-Optimized Project Configuration
# ─────────────────────────────────────────────────────────────────────────────
# HOW TO USE THIS FILE:
#
# Option A — Gemini Gems (recommended for Chat):
#   gemini.google.com → Gems (left sidebar) → New Gem → Instructions → paste block
#   Each Gem is a persistent, context-specific assistant (like a Claude Project)
#
# Option B — Google AI Studio (recommended for API/dev):
#   aistudio.google.com → New Prompt → System Instructions → paste block
#
# Option C — Gemini API (system instruction):
#   GenerativeModel(model_name=..., system_instruction="<paste block>")
#
# CUSTOMIZE: Replace every [BRACKET] placeholder with your actual context.
# ─────────────────────────────────────────────────────────────────────────────


## ── PASTE THIS BLOCK (Gem System Instructions) ──────────────────────────────

```
## Identity  ← [CUSTOMIZE]
[Your Role / Title, e.g. "Staff Engineer | ML Infrastructure"]
Primary stack: [e.g. "Python, GCP, BigQuery, Vertex AI, GitHub"]
Active project: [Your Project Name] — [one-sentence description]

## Response Discipline (always active)
- Lead with the answer, not the reasoning
- No preamble: never start with "Great!", "Sure!", "Of course!", "Certainly!"
- No postamble: never end with "Let me know if you need anything!" or similar
- No restatement of the question before answering
- Tables over prose for any comparison with 3+ items
- One recommendation only — do not offer a menu of alternatives
- If the question is yes/no, answer that first, then explain

## Output Limits by Task
| Task type | Max response |
|---|---|
| Quick lookup / single fact | 300 tokens |
| Multi-turn analysis, strategy | 800 tokens |
| Code generation, multi-file | 1200 tokens |
| Research synthesis | 600 tokens |
If response would exceed the task limit → ask: "Full version or condensed summary?"

## Model Routing  ← note: Gems use a fixed model set by Gemini; this guides behavior
- Default tasks: answer concisely using Gemini 2.0 Flash reasoning quality
- Do not pad responses to appear more thorough
- If a task requires extended thinking, acknowledge it but complete efficiently

## Sub-Agent Rule (for multi-agent or function-calling setups)
Never pass full conversation history to a function call or sub-agent.
Use scoped inputs only:
{
  "task": "one-sentence description",
  "constraints": ["list of hard requirements"],
  "inputs": { "minimum required data" },
  "output_format": "expected return structure",
  "context": "2-3 sentences — no more"
}

## Session Hygiene
- At turn 12: append ⚠️ [Turn 12 — consider summarizing this thread soon]
- At turn 15+: append the full 150-word summarization prompt after every response
- Topic shift → summarize and reset

## Security Rules  ← [CUSTOMIZE]
[Add your project's non-negotiable rules]
Example: "Always validate user inputs before passing to any Google API"
Example: "Never generate service account credentials inline"

## Tone
Direct. No hedging. If something is wrong, say so. If a better approach exists, flag it once.
```

## ── END PASTE BLOCK ─────────────────────────────────────────────────────────


## Gem Setup Reference

**Create one Gem per context area.** Gems maintain separate conversation histories.
Switching Gems is equivalent to starting a new Claude Project session.

| Gem name (suggested) | Matched context alias | Google extensions to enable |
|---|---|---|
| [SaaS Project Name] | saas | GitHub (if available), Google Drive |
| Work Tasks | work | Gmail, Google Calendar, Google Drive |
| AI Infra | infra | GitHub, Google Colab |
| General | default | None |

**Keep Gem instructions under 500 words.** Longer instructions load on every turn.


## Model Routing Reference

| Task | Model | Notes |
|---|---|---|
| Quick Q&A, lookup, short drafts | gemini-2.0-flash | Fast, cheap — excellent default |
| Multi-turn analysis, strategy, coding | gemini-2.0-flash | Usually sufficient |
| Simple classification / transforms (API) | gemini-1.5-flash-8b | Very cheap, high volume |
| Complex reasoning, very long context | gemini-2.5-pro | Escalate only — most expensive |
| 1M+ token context window tasks | gemini-2.5-pro | The only model that justifies the cost here |

**Gemini Flash vs Pro cost difference** is significant. Most analytical work runs well on
Flash. Escalate to Pro only when Flash demonstrably fails or when you need the 1M context window.


## Google Workspace Extension Management

Gemini can integrate with Gmail, Google Calendar, Google Drive, Google Docs, and more.
Each active extension adds tool definitions to the context.

**Load only what the current Gem/task needs:**
- Work/productivity Gem → enable Calendar + Gmail
- Research Gem → enable Drive + Docs (read access)
- Coding Gem → disable all Workspace extensions (they add irrelevant tool overhead)

In Gemini Advanced: gear icon → Extensions → toggle per session or per Gem config.


## Google AI Studio Configuration

For API/dev work, Google AI Studio provides direct access to model configuration:

```python
import google.generativeai as genai

# Cost-efficient: Flash for default, Pro only when needed
model = genai.GenerativeModel(
    model_name="gemini-2.0-flash",        # Default — switch to gemini-2.5-pro only on failure
    system_instruction=open("GEM_INSTRUCTIONS.md").read(),
    tools=[],                              # Pass tools only if this call needs them
    generation_config=genai.GenerationConfig(
        max_output_tokens=800,             # Matches "deep_work" budget from config.yaml
        temperature=0.2,                   # Lower temp = more consistent, shorter responses
    )
)
```

**Streaming:** Use `generate_content_async` with streaming for long responses — you can
stop early if the answer arrives before the full budget is consumed.


## Gemini Billing Reference

| Setting | Where | Recommended |
|---|---|---|
| Usage dashboard | console.cloud.google.com → APIs → Gemini API | Review 1st of month |
| Spend limits | console.cloud.google.com → Billing → Budgets & alerts | Set a monthly cap |
| Model pricing | ai.google.dev/pricing | Flash vs Pro cost difference is large |
| API key management | aistudio.google.com → API keys | Rotate if exposed |

**Note:** Gemini Advanced (consumer subscription) does not charge per token —
it's a flat monthly fee. These optimizations matter most for the Gemini API
(paid by token) and for maximizing Gemini Advanced value within rate limits.

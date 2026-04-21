# OpenAI System Prompt — Cost-Optimized Project Instructions
# ─────────────────────────────────────────────────────────────────────────────
# HOW TO USE THIS FILE:
#
# Option A — ChatGPT Projects (recommended):
#   ChatGPT → Select or create a Project → Instructions → paste the block below
#
# Option B — Custom GPT Builder:
#   ChatGPT → Explore → Create a GPT → Configure → Instructions → paste below
#
# Option C — OpenAI API (system message):
#   messages: [{ role: "system", content: "<paste block below>" }, ...]
#
# CUSTOMIZE: Replace every [BRACKET] placeholder with your actual context.
# The more specific the Identity section, the fewer tokens GPT-4o spends
# re-inferring context on each turn.
# ─────────────────────────────────────────────────────────────────────────────

## ── PASTE THIS BLOCK ────────────────────────────────────────────────────────

```
## Identity  ← [CUSTOMIZE]
[Your Role / Title, e.g. "Senior Product Manager | AI Security focus"]
Primary stack: [e.g. "Python, FastAPI, PostgreSQL, GCP"]
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

## Model Routing  ← [CUSTOMIZE escalate_policy if needed]
- Default: gpt-4o handles most tasks
- Simple transforms (formatting, classification): prefer gpt-4o-mini if available
- Escalate to o1/o3 only after gpt-4o fails twice on the same task
- Never auto-escalate because a task feels important

## Sub-Agent Rule
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
- Topic shift → summarize and reset; never carry raw history across domains

## Security Rules  ← [CUSTOMIZE]
[Add your project's non-negotiable security rules here]
Example: "Always validate user-submitted content before passing to any downstream API"
Example: "Never generate unsigned URLs — always include authentication parameters"

## Tone
Direct. No hedging. If something is wrong, say so. If a better approach exists, flag it once.
```

## ── END PASTE BLOCK ─────────────────────────────────────────────────────────


## ChatGPT Custom Instructions (Settings → Personalization)

ChatGPT has two custom instruction fields. Use them as follows:

**Field 1 — "What would you like ChatGPT to know about you?":**
```
[Your Role]: [Your Title and domain, e.g. "Product Manager focused on AI Security"]
Primary stack: [Your main technologies]
Active projects: [Your 1-2 main projects, one sentence each]
Preferred output: tables over prose, one recommendation not a menu, direct answers
```

**Field 2 — "How would you like ChatGPT to respond?":**
```
Respond concisely. Lead with the answer, not the reasoning.
No openers (Great!, Sure!, Certainly!). No closers.
Tables over prose for comparisons.
One recommendation, not a menu of options.
If I ask a yes/no question, answer it first.
```


## Model Routing Reference

| Task | Model | Why |
|---|---|---|
| Quick Q&A, fact lookup, short draft | gpt-4o | Fast, cheap, sufficient |
| Multi-turn analysis, strategy, coding | gpt-4o | Best default balance |
| Simple classification, formatting | gpt-4o-mini | 10–30× cheaper than gpt-4o |
| Hard multi-step reasoning, math proofs | o1 or o3-mini | Reasoning tokens worth it here |
| Maximum reasoning + long context | o3 | Use sparingly — most expensive |

**Cost warning on o1/o3:** These models charge for internal reasoning tokens that
aren't visible in the response. A single o3 call can cost as much as dozens of
gpt-4o calls. Only escalate when gpt-4o has demonstrably failed.


## Tool / Plugin Loading

ChatGPT natively supports browsing, code interpreter, and DALL-E as toggleable
capabilities. In Custom GPTs, you can also add Actions (HTTP endpoints).

**Disable what the current task doesn't need:**
- Browsing: enable only for research tasks
- Code Interpreter: enable only for data analysis or code execution tasks
- Custom Actions: configure only the endpoints the GPT actually uses

**OpenAI API function calling:**
Pass only the function definitions the current task requires in the `tools` array.
Each function definition adds tokens to every API call.

```python
# Efficient: scope tools to task
tools = [search_tool] if task_type == "research" else [code_tool]
response = client.chat.completions.create(
    model="gpt-4o",
    messages=messages,
    tools=tools   # Only what this call needs
)
```


## ChatGPT Memory Management

ChatGPT's built-in memory stores facts across sessions. Keep it scoped:
- **Store:** Your role, primary stack, project names, hard constraints
- **Don't store:** Session-specific decisions, temporary task context, one-off preferences

Check and prune memory monthly: Settings → Personalization → Manage memories
Stale memory entries add tokens to every conversation.


## Billing Reference

| Setting | Where | Recommended |
|---|---|---|
| Usage limits | platform.openai.com → Settings → Limits | Set a monthly $ cap |
| Usage dashboard | platform.openai.com → Usage | Review 1st of month |
| Cost per model | platform.openai.com → Pricing | Verify routing is working |
| API key rotation | platform.openai.com → API keys | Rotate if exposed in any log |

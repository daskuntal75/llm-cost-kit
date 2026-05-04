# OpenAI Cache Hygiene

> How to stop paying for prompt tokens you've already paid for.

OpenAI supports **automatic prompt caching** on GPT-4o, GPT-4o-mini, o3, o4-mini, and most current models. Unlike Claude, you don't opt in — the platform caches automatically. But automatic doesn't mean free. Understanding the mechanics prevents common waste patterns.

---

## How OpenAI caching works

- Caching applies to **input tokens only** (system prompt + conversation history prefix)
- Minimum eligible prefix: **1,024 tokens** — shorter prompts never cache
- Discount: **50% off** the standard input token rate for cached tokens
- TTL: approximately **5–60 minutes** (model-dependent, not published — treat as ~10 min in practice)
- No `cache_control` flag needed — it's entirely automatic
- Cache hits are visible in API usage dashboard under "cached input tokens"

**Break-even:** Unlike Claude (1.25× write / 0.1× read), OpenAI has no write premium. Every cache hit is pure savings. The only waste is paying for uncached prompts that could have cached.

---

## The four anti-patterns

### Pattern 1 — Prompts under 1,024 tokens

**What happens:** The 1,024-token threshold is a hard floor. Short system prompts (even 900 tokens) never cache, regardless of repetition. You pay full price every turn.

**Fix:** Pad lean system prompts to exceed 1,024 tokens. Add detailed output rules, a few examples, and routing guidelines. That one-time investment pays back on every subsequent call.

---

### Pattern 2 — Varying the prefix between calls

**What happens:** OpenAI caches the common *prefix* of your prompt. If your system prompt changes between calls (dynamic timestamps, user-specific content, rotating instructions), the cache prefix breaks and no caching occurs.

**Example of a cache-breaking pattern:**
```
System: You are a helpful assistant. Current time: 2026-05-04T14:32:11Z. User name: Alice.
```
The timestamp and user name change every call → zero cache hits.

**Fix:** Move stable content (system prompt body, output rules, tool definitions) to the start of the prompt. Move dynamic content (user name, timestamps, request-specific context) to the end, after the stable prefix.

```
System: [stable 1,200 tokens of rules + tool defs]   ← this caches
User:   [dynamic context — name, timestamp, request]  ← this doesn't need to
```

---

### Pattern 3 — Reasoning tokens on o-series (invisible cost)

**What happens:** o3, o4-mini, and other reasoning models generate internal "thinking" tokens that are billed at the **output token rate** — typically 3–4× the input rate. These tokens are not shown in the response and don't appear in your prompt, but they're a real cost. High `reasoning_effort` settings multiply this.

**Real example:** A $0.02 GPT-4o call becomes a $0.40 o3 call at `reasoning_effort: high` on a task that didn't require deep reasoning.

**Fix:** Use `reasoning_effort: low` or `medium` by default. Reserve `high` for demonstrably hard tasks (multi-step math, complex code generation). Don't use reasoning models for classification, extraction, or summarization — GPT-4o-mini handles these at a fraction of the cost.

| Task | Model | reasoning_effort |
|---|---|---|
| Classification, extraction, formatting | gpt-4o-mini | N/A |
| Chat, drafting, summarization | gpt-4o | N/A |
| Code, analysis, multi-step | o4-mini | low/medium |
| Research, complex reasoning | o3 | medium |
| Hard proofs, competition math | o3 | high |

---

### Pattern 4 — Tool definitions that change between calls

**What happens:** Tool/function definitions are part of the prompt prefix. If you add, remove, or reorder tools between calls, the cache prefix breaks. Common in multi-tenant apps where different users get different tool sets.

**Fix:** Normalize tool definitions. Sort them alphabetically and keep the list stable. If users need different tool subsets, use a fixed superset and filter in your app logic — don't change the prompt structure.

---

## Session hygiene (ChatGPT web + Projects)

| Situation | Action | Why |
|---|---|---|
| Related tasks | Stay in the same conversation | Conversation history caches; new chat restarts |
| Switching topics | Start a new chat with a summary | Don't carry unrelated context (costs tokens each turn) |
| Idle > 10 min | Treat cache as cold | Resume with a summary rather than assuming context is warm |
| Long threads | Summarize periodically | Conversation history grows; each turn pays for the full history |
| Projects (ChatGPT) | Use Project instructions for stable context | Cached per session, amortizes across turns |

---

## Cost tally (API)

End every API response audit with the cached vs uncached token split. In Python:

```python
usage = response.usage
print(f"Prompt: {usage.prompt_tokens} total / {usage.prompt_tokens_details.cached_tokens} cached")
print(f"Completion: {usage.completion_tokens}")
cache_pct = usage.prompt_tokens_details.cached_tokens / usage.prompt_tokens * 100
print(f"Cache hit rate: {cache_pct:.1f}%")
```

Target cache hit rate: **≥ 60%** on stable workloads. Below 20% means your prefix is unstable.

---

## OpenAI vs Claude: cache mechanics at a glance

| Dimension | OpenAI | Claude |
|---|---|---|
| Cache control | Automatic | Explicit `cache_control` blocks |
| Minimum size | 1,024 tokens | 1,024 tokens |
| Write cost | No premium (automatic) | 1.25× input rate |
| Read savings | 50% off input tokens | 90% off input tokens (0.1×) |
| TTL | ~10 min (unpublished) | 5 min (Code) / 1h (API flag) |
| Visibility | Usage dashboard (cached token count) | No efficiency score in console |
| Best for | Low-friction caching | Maximum savings when you control the pattern |

**Summary:** OpenAI's automatic caching is lower friction but lower ceiling. Claude's manual caching requires discipline but delivers 90% savings on reads vs 50% on OpenAI — worth the extra setup on high-volume workloads.

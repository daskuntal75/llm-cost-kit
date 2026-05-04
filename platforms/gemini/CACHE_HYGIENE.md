# Gemini Cache Hygiene

> Gemini has the most transparent caching system of the three major LLMs — but also the most ways to over-spend if you don't understand the storage model.

Gemini 1.5 Pro/Flash and Gemini 2.5 Pro/Flash support **explicit Context Caching** via the API. Unlike Claude (manual `cache_control` blocks) or OpenAI (fully automatic), Gemini requires you to explicitly create a cache object — and charges a small hourly storage fee while it exists.

---

## How Gemini caching works

- You create a cache with `cacheContent` — it lives as a named resource
- Minimum size: **32,768 tokens** (hard requirement)
- Storage cost: small hourly fee per 1M cached tokens (published in Gemini pricing)
- TTL: **1 hour default**, configurable from minutes to days/months
- Discount on cache reads: significant (varies by model — check current pricing)
- Works with: text, images, audio, video, documents — multimodal content
- Cache is reusable across multiple API calls (unlike Claude's per-session TTL)

**Key difference from Claude/OpenAI:** You pay to *keep* the cache alive. Short TTLs minimize storage cost. Long TTLs reduce cache write frequency. The optimal TTL depends on your call volume.

---

## The four anti-patterns

### Pattern 1 — Using Pro when Flash handles it

**What happens:** Gemini Pro costs approximately 5–10× more than Flash per token. Most tasks don't require Pro's capabilities. Using Pro by default wastes money on every call.

**Real example:** Summarizing 50 documents with Gemini Pro = ~$2.50. The same task with Flash = ~$0.25. Same quality for summarization tasks.

**Fix:** Flash is your daily driver. Escalate to Pro only when Flash explicitly fails or produces noticeably worse output on the second attempt.

| Task | Model | thinking_budget |
|---|---|---|
| Classification, extraction, formatting | Flash | 0 (disabled) |
| Summarization, translation, chat | Flash | 256 |
| Code generation, analysis | Flash / Pro | 1024 |
| Complex multi-step reasoning | Pro | 2048–4096 |
| Long-context document review (>500K tokens) | Pro | 1024 |

---

### Pattern 2 — High thinking_budget by default

**What happens:** Gemini 2.5 uses `thinking_budget` to cap reasoning tokens. These tokens are billed at the output rate. An uncapped budget on simple tasks can turn a $0.01 call into a $0.30 call.

**Fix:** Set `thinking_budget: 0` (disabled) for extraction/classification. Set 256 for routine chat. Only go above 1024 for genuinely complex reasoning tasks.

```python
# Explicitly cap reasoning on simple tasks
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config={"thinking_config": {"thinking_budget": 256}}
)
```

---

### Pattern 3 — Context caching a content block that changes frequently

**What happens:** You pay a storage fee for the cache while it exists + a write fee when you create it. If the content changes every hour, you're paying to create + delete caches continuously — often more expensive than just sending the tokens uncached.

**Break-even calculation:**
```
cache_write_cost + storage_cost_per_hour × hours_in_use < uncached_input_cost × number_of_calls
```

Rule of thumb: context caching is worth it when the same content is reused across **≥ 5 calls** within the TTL window.

**Fix:** Cache only stable, large content blocks — not per-request or per-user content. Good candidates:
- System prompts + output rules (stable, always included)
- Reference documents (product spec, codebase context, FAQ)
- Tool definitions (stable across users)

---

### Pattern 4 — Full-file context dumps past the coherence cliff

**What happens:** Gemini's 1M–2M context window is a feature, not a workflow pattern. Dumping entire codebases, full meeting transcripts, or unfiltered document sets degrades model coherence past ~200K tokens on most tasks — and you still pay for every token.

**Fix:** Filter before injecting. Send only the relevant diff, not the full file. Send only the relevant meeting section, not the entire transcript. Use Gemini's grounding feature for web-current questions instead of injecting fresh documents yourself.

---

## Context caching setup (API)

```python
import google.generativeai as genai
from datetime import timedelta

# Create a cache for your stable system context
cache = genai.caching.CachedContent.create(
    model="gemini-2.5-pro",
    contents=[system_prompt, reference_docs],
    ttl=timedelta(hours=4)  # set based on your call volume
)

# Use the cache in subsequent calls
model = genai.GenerativeModel.from_cached_content(cached_content=cache)
response = model.generate_content("Your per-request prompt here")

# Clean up when done
cache.delete()
```

---

## Grounding discipline

Google Search grounding adds latency and cost to every call. Use only when:
- The question requires information after your knowledge cutoff
- Real-time prices, stock quotes, news, or live data
- Fact-checking recent events

Do NOT use grounding for:
- General knowledge questions (model already knows)
- Code generation, summarization, classification
- Analysis of content you provide in the prompt

---

## Session hygiene (Gemini web app + AI Studio)

| Situation | Action | Why |
|---|---|---|
| Related tasks | Stay in the same conversation | Conversation history is free within session |
| Long conversations | Summarize at ~50K tokens | Coherence starts degrading in long Gemini threads |
| New topic | New chat | Don't carry unrelated context |
| AI Studio prototyping | Explicit cache for system context ≥ 32K tokens | Pays back after ~5 calls |
| Personal context (Gemini app) | Keep under 200 words | Loads every session — keep it lean |

---

## Gemini vs Claude: cache mechanics at a glance

| Dimension | Gemini | Claude |
|---|---|---|
| Cache control | Explicit `CachedContent` API | Explicit `cache_control` blocks |
| Minimum size | 32,768 tokens | 1,024 tokens |
| Write cost | One-time + storage fee | 1.25× input rate |
| Read savings | Varies by model (~75%+ on Pro) | 90% off (0.1×) |
| TTL | Configurable (minutes to months) | 5 min (Code) / 1h (API) |
| Visibility | Full — you know exactly what's cached | No console efficiency score |
| Multimodal | Yes — images, audio, video, docs | Text only |
| Best for | Large stable contexts, multimodal, long TTL | High-read-frequency text workloads |

**Summary:** Gemini's explicit cache API is the most transparent of the three — you have full control over what's cached, when it expires, and can measure storage cost directly. Claude wins on maximum read savings (90% vs ~75%+). OpenAI wins on zero-friction caching.

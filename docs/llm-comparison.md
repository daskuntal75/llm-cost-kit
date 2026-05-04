# Claude vs OpenAI vs Gemini — Cost, Cache, and UX Comparison

> Which platform does the most to help you control what you spend?

Measured across five dimensions: caching mechanics, cost visibility, model routing, instruction architecture, and developer UX. Data from real-world usage and published pricing as of May 2026.

---

## Quick verdict

| Dimension | Winner | Runner-up | Lagging |
|---|---|---|---|
| Cache savings ceiling | **Claude** (90% read discount) | Gemini (~75%) | OpenAI (50%) |
| Cache transparency | **Gemini** (explicit API, configurable TTL) | OpenAI (usage dashboard) | Claude (no efficiency score) |
| Zero-friction caching | **OpenAI** (automatic, no config) | — | Claude + Gemini (manual) |
| Cost visibility (billing UI) | **OpenAI** | **Gemini** | Claude (conflates charge types) |
| Model routing granularity | **Claude** (3 tiers + effort levels) | OpenAI (multiple models + reasoning_effort) | Gemini (Flash/Pro + thinking_budget) |
| Instruction layer architecture | **Claude** (7 layers) | OpenAI (3 layers) | Gemini (2 layers) |
| Long-context cost efficiency | **Gemini** (Flash + 1M tokens) | Claude (Haiku) | OpenAI (gpt-4o-mini) |

---

## 1. Caching mechanics

### Claude
- **Manual control** via `cache_control` blocks in prompt
- Write: **1.25× input rate**. Read: **0.1× input rate** (90% savings)
- TTL: 5 min (Code sessions), 1h (API with explicit flag)
- Minimum: 1,024 tokens
- **Best when:** You control the prompt structure and want maximum savings on high-read workloads

**Anti-patterns:** Mini-sessions, idle>5min cliffs, CI/E2E retry loops, write-then-walk. Full analysis: [`core/CACHE_HYGIENE.md`](../core/CACHE_HYGIENE.md)

### OpenAI
- **Fully automatic** — no configuration needed
- Write: **no premium** (automatic). Read: **50% off input tokens**
- TTL: ~10 min in practice (not published)
- Minimum: 1,024 tokens
- **Best when:** You want caching without thinking about it

**Anti-patterns:** Short prompts under 1,024 tokens (never cache), varying prefix across calls, using reasoning models for simple tasks. Full analysis: [`platforms/openai/CACHE_HYGIENE.md`](../platforms/openai/CACHE_HYGIENE.md)

### Gemini
- **Explicit `CachedContent` API** — you create and manage cache objects
- Write: one-time + **hourly storage fee**. Read: ~75%+ savings (model-dependent)
- TTL: configurable (1h default, up to months)
- Minimum: 32,768 tokens (10× Claude/OpenAI threshold)
- **Best when:** You have large stable contexts (32K+), multimodal content, or long-lived reference data

**Anti-patterns:** Caching frequently-changing content, using Pro when Flash suffices, uncapped thinking_budget, 500K+ context dumps. Full analysis: [`platforms/gemini/CACHE_HYGIENE.md`](../platforms/gemini/CACHE_HYGIENE.md)

---

## 2. Cost visibility

### Claude — needs the most improvement
- Billing UI combines API direct charges and subscription overages in a single display
- No cache efficiency score in the console
- No `resets_on` in Admin API — forces developers to hardcode billing reset dates
- "Usage Limit" errors show no type, no reset time
- No pre-limit alerts

→ 6 formal enhancement requests filed: [github.com/anthropics/anthropic-sdk-python/issues](https://github.com/anthropics/anthropic-sdk-python/issues)

### OpenAI — solid
- Dashboard shows cached vs uncached token split per request
- Spend breakdown by model, by day
- Usage limits with specific error codes
- API: `usage.prompt_tokens_details.cached_tokens` in every response
- No formal cache amortization ratio, but enough raw data to compute it

### Gemini — best for control freaks
- Context caching dashboard shows exactly what's cached, TTL, storage cost
- AI Studio gives per-call token breakdown with cache status
- `thinking_tokens` visible separately from output tokens
- Flash vs Pro costs clearly separated
- Google Cloud Billing integration for enterprise tracking

---

## 3. Model routing

### Claude
Three model tiers + explicit effort levels — most granular control available:

| Model | Use case | Approx. cost |
|---|---|---|
| Haiku 4.5 | Classification, extraction, quick lookups | Lowest |
| Sonnet 4.6 | Chat, summaries, routine code | Medium |
| Opus 4.7 | Architecture, security, complex reasoning | Highest |

Plus `effort: low/medium/high/xHigh` for each model. Two-axis optimization.

### OpenAI
Multiple models with clear cost/capability tiers:

| Model | Use case | Approx. cost |
|---|---|---|
| gpt-4o-mini | Classification, extraction, simple tasks | Lowest |
| gpt-4o | Chat, drafting, routine code | Medium |
| o4-mini | Code, analysis, reasoning | Medium-high |
| o3 | Complex multi-step, research | Highest |

`reasoning_effort: low/medium/high` for o-series. Good routing options but no "effort" parameter for non-reasoning models.

### Gemini
Binary Flash/Pro split + thinking_budget:

| Model | Use case | Approx. cost |
|---|---|---|
| Gemini 2.5 Flash | Most tasks (daily driver) | Lowest |
| Gemini 2.5 Pro | Complex reasoning, long context | Highest |

Simpler decision tree but fewer intermediate options. Flash handles 80%+ of workloads at a fraction of Pro cost — the default choice is obvious.

---

## 4. Instruction layer architecture

### Claude — 7 layers (most powerful)
L1 (Cowork project, every turn) → L2 (Cowork global, per session) → L3 (Code CLAUDE.md) → L4 (User Prefs, universal) → L5 (Memory) → L6 (Skills, lazy) → L7 (Chat project)

Where you put an instruction determines when it fires and what it costs. Full architecture: [`core/HIERARCHY.md`](../core/HIERARCHY.md)

### OpenAI — 3 layers
Custom Instructions (L4 equivalent, always-on) → Project Instructions (L7 equivalent, per project) → Custom GPT system prompt (L6 equivalent, per GPT)

Simpler but fewer control points. No Cowork-equivalent real-time layer.

### Gemini — 2 layers
Personal Context (L4 equivalent, always-on) → Gem instructions (L6 equivalent, per Gem)

Fewest layers. Compensate with focused Gems for distinct workflows. No per-project instruction layer.

---

## 5. Developer UX

| Feature | Claude | OpenAI | Gemini |
|---|---|---|---|
| Admin API for usage | ✅ (gaps documented) | ✅ | ✅ Google Cloud |
| Programmatic instruction updates | Partial (Code + Chat; not Cowork) | ✅ | ✅ |
| CLI tooling | Claude Code (exceptional) | N/A | N/A |
| Webhook / usage alerts | ❌ (filed as issue) | Basic | Google Cloud alerting |
| Cache hit visibility | ❌ no console score | ✅ per-call | ✅ explicit cache objects |
| Billing split (subs vs API) | ❌ conflated | ✅ | ✅ |
| Multimodal caching | ❌ text only | ❌ text only | ✅ all modalities |

---

## Bottom line — when to use which

**Use Claude when:**
- You want maximum cache savings on text workloads and can invest in session discipline
- You're doing heavy software development (Claude Code is best-in-class)
- You need fine-grained model/effort routing across a complex workflow
- You're building a 7-layer instruction architecture for a multi-surface AI workflow

**Use OpenAI when:**
- You want caching that just works with no setup
- Your team can't enforce session discipline
- You need the most mature API ecosystem + documentation
- Reasoning models (o-series) are central to your workload

**Use Gemini when:**
- You have large multimodal contexts (32K+ tokens, images, audio, video)
- You want the most transparent cache control
- Long-context tasks dominate your workload (Flash at 1M tokens is cheapest per-token)
- You're already in the Google Cloud ecosystem

---

*Full open-source cost kit (Claude + OpenAI + Gemini): [github.com/daskuntal75/llm-cost-kit](https://github.com/daskuntal75/llm-cost-kit)*
*Enhancement requests filed with Anthropic: [github.com/anthropics/anthropic-sdk-python/issues](https://github.com/anthropics/anthropic-sdk-python/issues)*

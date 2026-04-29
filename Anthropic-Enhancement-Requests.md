# Enhancement Requests for Anthropic

**From:** Kuntal Das, Director Product Management · daskuntal75@github
**Date:** April 28, 2026
**Plan:** Max ($200/mo, 20x Pro)
**Context:** Heavy daily user across Claude Chat, Cowork, Claude Code · Founder of CareerBound.ai (production app on Anthropic API) · Built and shared `llm-cost-kit` (Apache 2.0) — open-source toolkit deployed by other Claude users to manage instructions across surfaces

---

## TL;DR for the busy reader

Two opportunities, one offer.

**Opportunity 1 — Subscription transparency.** Heavy users can't currently estimate where they stand against plan throttle thresholds. They hit a wall, wait for reset, hope it doesn't repeat. A simple usage % indicator would fix it. Detailed proposal below.

**Opportunity 2 — Hierarchy documentation.** The instruction precedence model across User Preferences, Cowork Global, Cowork Project, Chat Project, Code CLAUDE.md, Skills, and Memory is undocumented. I learned it through trial and error and wrote a 7-layer guide that has been adopted by other users. This pattern needs to be formalized in your docs. Detailed proposal below.

**The offer.** I want to work on Anthropic's customer experience. My LinkedIn is in the footer. The work I've done in `llm-cost-kit` is essentially a sample of what I'd build for Claude users at scale.

---

## Opportunity 1 — Make subscription throttle thresholds observable

### The problem (real user data)

I am on the Max 20x plan ($200/mo). My month-to-date usage on Claude Code in April 2026, measured by `ccusage` (a community CLI), is **$706.13 in retail-equivalent value** — 3.53× my monthly subscription fee.

This is a great deal. But three downstream issues come from not knowing where I stand against the plan's actual throttle threshold:

| Issue | Impact |
|---|---|
| **I don't know if I'm getting close to a throttle event** | Sudden "limit reached" messages mid-task break flow. I've had to manually wait hours for resets. |
| **I can't right-size my plan** | Am I a Max 20x user, or could I save $100/mo by downgrading to Max 5x? Without knowing where the cap actually is, the only way to find out is to downgrade and see if I get throttled. That's expensive risk. |
| **I can't predict capacity for big work** | Before starting a multi-hour agentic run, I should know "this will use ~30% of your remaining quota". Currently, no way to know. |

### Why `ccusage` doesn't solve this

`ccusage` calculates retail-equivalent USD. That's useful for "am I extracting value from my subscription?" but **it doesn't map to plan quota**. The Max plan's real limit is some opaque combination of tokens, requests, time-windowed rate limits, and model-specific multipliers — none of which `ccusage` knows about.

### What's needed

A simple usage-vs-quota signal exposed somewhere accessible. In rough order of how good they'd be:

| Option | Effort (Anthropic) | Value (User) |
|---|---|---|
| **A. Add a percentage in Settings → Usage:** "67% of your monthly quota used" | Low (you already calculate this internally to throttle me) | High |
| **B. Same %, exposed via a simple billing API** (`GET /v1/me/usage`) | Medium | High — enables tools, dashboards, status-line integrations |
| **C. Same %, exposed in Claude Code statusline** | Medium | Highest — visible during work, not just when I check Settings |
| **D. Detailed dashboard with per-day quota burn** | Higher | Nice-to-have, not essential |
| **E. Pricing transparency: "Max 20x = X tokens/day equivalent"** | Highest (requires nailing down the actual cap policy) | Nice-to-have |

**Minimum viable improvement: Option A.** Just one number. "You've used 47% of your monthly quota." Even if approximate, it'd change everything.

### What I'd build with this

If Option B existed, I'd update `llm-cost-kit` to pull the percentage daily and have Claude Code display it in the cost tally on every response. Users would always know where they stand. No more surprise throttle events.

### Empirical workaround I've built (because there's no other choice)

I track throttle events manually. When Claude tells me "limit reached, wait until X", I log it via:

```
update-claude-cost --throttle --surface code --reset-at "21:00" --context "<note>"
```

Aggregated over a month, throttle hit count + downtime minutes give me an empirical signal: zero hits = downgrade candidate, 3+ hits or 500+ minutes = correctly sized.

This works, but it's a band-aid. The real signal lives on Anthropic's side and would be a one-line API to expose.

---

## Opportunity 2 — Document and formalize the instruction hierarchy

### The problem

Claude users have at least seven distinct places to put instructions:

| Layer | Surface | Loads | Reload cost |
|---|---|---|---|
| L1 | Cowork project instructions | Every turn | Highest — multiplies by turn count |
| L2 | Cowork global instructions | Once per session | Medium |
| L3 | Claude Code CLAUDE.md | Once per session | Medium |
| L4 | User Preferences (account-wide) | Once per session, all surfaces | Low — most efficient layer |
| L5 | Memory (auto-generated + Cowork native panel) | Auto-injected | Variable |
| L6 | Skills (lazy-loaded) | Only on trigger | Pay-per-use |
| L7 | Chat project instructions | Once per session | Low-medium |

**None of this is documented.** Worse, several non-obvious behaviors aren't documented either:

1. **Cowork only loads skill _descriptions_, not full SKILL.md bodies.** I learned this only after spending a session debugging why my memory-first skill wasn't taking effect. The body loads on `@invocation` only. Format/behavior directives must therefore live in L1 or L2, not in the skill body. This is a critical insight — and it's nowhere in your docs.

2. **L1 instructions reload on every Cowork turn.** A 4,000-token L1 across 30 turns = 120,000 input tokens just to repeat context. Most users don't realize this and put long content in L1.

3. **There's no documented "decision tree" for which layer to use.** I built one (attached as image) and it's now part of `llm-cost-kit`.

### Real-world impact

Before I figured this out, my CareerBound.ai Cowork project had ~4,000 tokens of L1 reloading every turn. After moving universal rules to L2 and lean per-project rules to L1: ~130 tokens per turn. **96% reduction on per-turn project context overhead.** That's real money on retail API rates and real value on Max plan (more headroom before throttle).

### What's needed

A canonical doc on `docs.anthropic.com` (or `support.claude.com`) that:

1. **Names the layers.** Use a numbering or naming scheme everyone can reference.
2. **Specifies the loading semantics.** When does each layer load? What's its caching behavior? What's its size budget?
3. **Documents the precedence rules.** When two layers contradict, which wins? (My current understanding: more specific layer wins, but it's not always clear.)
4. **Provides the decision tree.** "I want to add an instruction. Which layer should I use?"
5. **Calls out non-obvious behaviors.** Especially: Cowork loads skill descriptions only; format directives must be in L1/L2 to fire.
6. **Includes a token-budget cheat sheet.** "L1 should be < 300 words because it reloads each turn. L4 can be richer because it loads once."

### What I've already built

The `llm-cost-kit` repo includes:

- `core/HIERARCHY.md` — full 7-layer guide with decision tree
- A visual diagram of the hierarchy
- A flowchart showing how to choose the right layer
- L1, L2, L3, L7 templates for each layer

I'd be happy for Anthropic to fork it, integrate concepts, or commission an official version.

---

## Opportunity 3 (the offer)

I want to work on Anthropic's customer experience.

**Background:**
- 15 years building enterprise products. Director-level PM. Currently transitioning roles.
- Founder of CareerBound.ai — production B2B SaaS, runs on Anthropic API.
- Built and open-sourced `llm-cost-kit` (Apache 2.0) — a 4-platform toolkit that helps Claude users (and OpenAI/Gemini users) manage instructions efficiently. Includes a 7-layer hierarchy guide, three skills, an `update-claude-cost` CLI for tracking subscription value, and SVG diagrams + decision trees that other users have started embedding in their own setups.
- I think about cost optimization and developer/user experience full-time.

**What I could do at Anthropic:**
- Make Subscription Transparency a real product surface (Opportunity 1)
- Write the canonical Instruction Hierarchy guide (Opportunity 2)
- Drive end-to-end cost-management UX across Claude.ai + Code + API
- Build the "right-sizing your plan" experience that I'm currently doing manually with my CLI
- Find the next 10 friction points for power users and fix them before customers ask

**The simplest interview process:** look at `github.com/daskuntal75/llm-cost-kit` and the hierarchy guide it ships with. That's a sample of what I'd build for Anthropic.

I'm `daskuntal75` on GitHub. Reach out: kuntal.das@careerbound.ai.

---

## Appendix — What's in `llm-cost-kit`

Released under Apache 2.0. Currently at v3.4. Free for anyone to use, fork, or commercialize.

| Component | What it does |
|---|---|
| `core/HIERARCHY.md` | The 7-layer instruction hierarchy guide with decision tree |
| `core/AUTO_SYNC.md` | fswatch + GitHub auto-sync architecture for keeping instructions in sync across machines |
| `core/PRINCIPLES.md` | Cost optimization principles |
| `core/SESSION_HYGIENE.md` | When to `/clear` vs `/compact` |
| `platforms/claude/` | Claude-specific skills + templates |
| `platforms/openai/` | OpenAI Custom GPT system prompt + Custom Instructions |
| `platforms/gemini/` | Gemini Gem instructions + Personal Context |
| `platforms/claude/cumulative/update-claude-cost.sh` | The 338-line CLI that powers value-ratio + throttle event tracking |
| `diagrams/` | SVG + PNG of hierarchy diagram and decision tree |

The kit reflects ~3 weeks of trial-and-error optimization. If Anthropic wants to integrate any of these patterns into official documentation, please do.

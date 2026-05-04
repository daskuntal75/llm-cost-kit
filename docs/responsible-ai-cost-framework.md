# You're Paying for AI Work That Never Happened
## A Plain-English Framework for Responsible Claude Usage

> **The short version:** 40% of a typical heavy Claude subscription goes to invisible waste. This document explains what's causing it, why it matters beyond your own bill, and exactly how to fix it — no technical background required.

---

## The Problem in One Sentence

Every time you start a Claude session, it "saves its memory" of your files and rules. That save costs money. If you close the session (or go idle for 5 minutes) before Claude has a chance to re-use that saved memory, you paid for a save that was never read back.

Do that enough times, and you've wasted 40% of your subscription.

---

## Part 1: The Numbers

### What the audit found

A one-month measurement of a heavy Claude Max subscription ($100/mo) revealed:

| What happened to the $100 | Amount |
|---|---|
| Useful AI work (answers, code, analysis) | ~$60 |
| **Wasted "saves" that were never re-read** | **~$40** |
| Cache efficiency score (target: ≥ 0.5) | **0.16** — badly off target |

That $40 didn't disappear into thin air — it paid for real GPU compute that ran, processed your files, and then sat idle until it expired 5 minutes later with nothing to show for it.

There's a second hidden cost on top: Claude's Opus 4.7 model ships with a new tokenizer that [produces up to 35% more tokens for the same text](https://www.finout.io/blog/claude-opus-4.7-pricing-the-real-cost-story-behind-the-unchanged-price-tag). Your bill can rise even when the published price doesn't change.

---

### Why Anthropic cares too

This isn't only a personal finance issue. Anthropic hit a [$30 billion annualized revenue run rate in April 2026](https://www.madrona.com/price-of-tokenmaxxing-claude-explosive-growth-cost-of-intelligence/). At that scale, wasted cache writes across millions of users represent a material fraction of total inference compute — compute that could be serving productive work instead.

A pattern called ["tokenmaxxing"](https://www.cnbc.com/2026/04/17/ai-tokens-anthropic-openai-nvidia.html) — Silicon Valley engineering systems specifically to maximize token consumption — is further inflating demand beyond genuine usage. The Information reports that [Anthropic is already shifting toward usage-based pricing](https://www.theinformation.com/articles/anthropic-changes-pricing-bill-firms-based-ai-use-amid-compute-crunch) as a response to compute scarcity.

---

### Why the whole industry cares

AI compute is genuinely running out:

- **Token demand exploded.** Weekly token usage across major platforms grew [3,800% in just 12 months](https://openrouter.ai/state-of-ai). Token processing jumped from 6 million per minute in October 2025 to [15 billion per minute by March 2026](https://www.clarifai.com/blog/gpu-shortages-2026). In China, daily token calls rose from 100 billion in early 2024 to [140 trillion in March 2026 — a 1,000-fold increase in two years](https://technode.com/2026/04/17/china-authority-says-daily-ai-token-usage-exceeds-140-trillion-in-march-up-over-40-vs-end-2025/).

- **GPU supply can't keep up.** New AI chips take [36–52 weeks to order](https://www.clarifai.com/blog/gpu-shortages-2026). The memory chips inside every AI accelerator are made by just three companies, and SK Hynix's CFO stated plainly: *"We have already sold out our entire 2026 HBM supply."* Microsoft, Google, Meta, and Amazon have already reserved [most of NVIDIA's output through end of 2026 and into 2027](https://vexxhost.com/blog/gpu-capacity-crisis-ai-infrastructure-2026/).

- **Energy is the next wall.** AI data centers now consume [4.4% of all US electricity](https://www.technologyreview.com/2025/05/20/1116327/ai-energy-usage-climate-footprint-big-tech/), with that figure projected to reach [1,050 terawatt-hours by 2026](https://www.allaboutai.com/resources/ai-statistics/ai-environment/) — placing AI between Japan and Russia in global energy consumption. Google alone will spend [$75 billion on AI infrastructure in 2025](https://www.technologyreview.com/2025/05/20/1116327/ai-energy-usage-climate-footprint-big-tech/).

**The conclusion:** Every wasted token is a GPU cycle that didn't serve a productive outcome, at a moment when GPU cycles are the scarcest resource in the global economy.

---

## Part 2: How the Waste Happens — 4 Habits

Think of Claude's session cache like a parking meter. Every session, you feed it money. If you come back before time's up, the meter is still running — great. But if the meter expires before you return, you have to feed it again from scratch.

### Habit 1 — One task, one session

**What happens:** You open Claude to fix a bug. You fix it. You close Claude. You open it again to write a test. That's two sessions. Each one loaded all your project files into cache. Each one exited before Claude could re-read them.

**The cost:** 2 full saves. 0 re-reads. 100% waste on both.

**The fix:** Do related work in the same session. Ten tasks in one session = one save, ten re-reads.

---

### Habit 2 — One question, then gone

**What happens:** You open Claude to check a function signature. Claude loads your entire project (5,000+ tokens → expensive save). You get your answer. You close the window.

**The cost:** Full save paid for. Zero re-reads. Net result: you paid for the save with nothing to show.

**The fix:** Before closing any session, ask one more question — any question. Even "summarize what we just did." That single re-read starts paying back the save.

---

### Habit 3 — Walk away for 5 minutes, then come back

**What happens:** Claude's saved memory expires after exactly 5 minutes of inactivity. If you step away and then continue, Claude saves everything from scratch — full cost, again — even though you never closed the window.

**The fix:** Decide before the 5-minute mark:
- Still working? → Keep going (one message keeps the timer alive)
- Done for now? → Type `/clear` before stepping away — intentional reset is always cheaper than an accidental re-save

---

### Habit 4 — The Debug Loop *(most expensive by far)*

**What happens:** A test fails in CI. You open Claude, paste the error, make one fix, push, close Claude. It fails again. You repeat.

**Real cost measured:** 8 sessions in one day to fix a test suite. Each session loaded ~1.4 million tokens of project context. Each session exited after 1–2 messages.

| | Cost |
|---|---|
| 8 micro-sessions (actual) | **$17.83** |
| Same 8 fixes in 1 session (what it should have cost) | **~$2–3** |
| Waste | **$15+** |

**The fix:** Stay in ONE session for an entire debugging cycle. Use `/compact` if the conversation gets too long — but never restart mid-debug.

---

## Part 3: The Cache Efficiency Score

You can track how efficiently you're using cache with one number:

```
efficiency score = money spent re-reading ÷ money spent saving
```

| Score | What it means | What to do |
|---|---|---|
| 0.5 or above | Healthy — your saves are paying off | Nothing |
| 0.2 – 0.5 | Watch — some waste building up | Review your session habits |
| Below 0.2 | Problem — most saves are wasted | Apply all 4 fixes above |

The April 2026 audit score: **0.16**. Target: 0.5+.

Check yours: `cache-efficiency --month YYYY-MM`

---

## Part 4: The 7-Layer Fix — Where You Put Instructions Matters

Here's the second major finding, and the one most people miss entirely:

**It's not just about what you tell Claude. It's about where you put those instructions.**

Claude has 7 places where you can write instructions. Each one loads at a different frequency. An instruction that loads on every single message costs dramatically more than one that loads once at the start of a session.

The analogy: Imagine printing your company's full employee handbook and stapling it to every email you send. The information is correct — but the cost of sending it every time is absurd. Better to mail the handbook once and just note the relevant section in each email.

### The 7 Layers — Visual Guide

```
┌─────────────────────────────────────────────────────────────────┐
│  LOAD FREQUENCY     LAYER           WEIGHT BUDGET               │
│                                                                  │
│  ████████████████   L1              < 200 tokens (~150 words)   │
│  Every message      Cowork Project  RUTHLESSLY SHORT             │
│                                                                  │
│  ██████████████     L2              < 1,000 tokens              │
│  Every session      Cowork Global   Keep light                  │
│                                                                  │
│  ██████████████     L3 (Project)    < 2,000 tokens              │
│  Every session      Code CLAUDE.md  Moderate                    │
│                                                                  │
│  ██████████████     L3 (Global)     < 1,000 tokens              │
│  Every session      ~/.claude/      Keep light                  │
│                     CLAUDE.md                                    │
│                                                                  │
│  ██████████████     L4              < 500 tokens                │
│  Every session      Code Prefs      Light                       │
│                                                                  │
│  ████               L5              No limit                    │
│  On demand only     Memory Files    Load only when needed       │
│                                                                  │
│  ████               L6              No limit                    │
│  On demand only     Skills          Load only when active       │
│                                                                  │
│  ██████████████     L7              < 2,000 tokens              │
│  Every session      Chat Project    Moderate                    │
└─────────────────────────────────────────────────────────────────┘
  ↑ High frequency = small budget     Low frequency = larger budget ↑
```

### The simple rule

> The more often a layer loads, the lighter it must be.

Real example: One project's L1 (every-message) block was 4,000 tokens — the equivalent of a 3,000-word document sent with every single prompt. Trimmed to 130 tokens with identical instructions. Result: **−97% per-turn cost** with zero loss of quality.

### Decision guide: Where does this instruction go?

```
New instruction to add
        │
        ▼
Does it need to apply on EVERY SINGLE MESSAGE?
├── YES → L1  (keep under 150 words, no exceptions)
└── NO
        │
        ▼
Does it apply to ALL projects (not just one)?
├── YES → L2 (Cowork global) or L3 Global (Code ~/.claude/CLAUDE.md)
└── NO
        │
        ▼
Is it specific to one project or codebase?
├── YES → L3 Project (Code project CLAUDE.md)
└── NO
        │
        ▼
Is it reference info you only need sometimes?
├── YES → L5 Memory (free when not loaded)
└── NO
        │
        ▼
Is it a specialized skill for specific task types?
├── YES → L6 Skills (only active when that task type is running)
└── NO → L7 Chat or L4 Code Preferences depending on surface

GOLDEN RULE: When in doubt, put it deeper.
Higher layer number = less frequent loading = lower cost.
```

### What goes where

| Instruction type | Best layer | Why |
|---|---|---|
| Tone and response style | L1 | Shapes every single message |
| Cost tracking dashboard | L3 / L7 | Session-scoped; auto-refreshed hourly |
| Model routing rules | L3 | Once per session is enough |
| Security requirements | L3 | Project-specific, session-scoped |
| Project history and decisions | L5 Memory | Only relevant sometimes |
| Specialized task instructions | L6 Skills | Only relevant for specific work |

---

## Part 5: The Automation Pipeline

Once your instructions are in the right layers, there's one more problem: the cost tracking numbers in those instructions go stale within hours.

The solution is a five-step background script that runs automatically every hour:

```
Step 1: Read your Claude usage from local logs
Step 2: Pull your API spend from Anthropic (Admin API)
Step 3: Update your Chat project instructions
Step 4: Update your Cowork global instructions
Step 5: Update your Code global instructions (CLAUDE.md)
```

Set it up once. It runs quietly in the background. Every Claude response you get — in any surface — will show accurate, current cost data.

Setup: `github.com/daskuntal75/llm-cost-kit` → `platforms/claude/scripts/`

---

## Part 6: Results

Applying this framework to one Claude Max subscription:

| Metric | Before | After | Change |
|---|---|---|---|
| Words sent with every single message | ~3,000 | ~100 | −97% |
| Tokens loaded at session start | ~7,500 | ~800 | −89% |
| Cost per conversation turn | ~$0.04 | ~$0.005 | −88% |
| Monthly subscription waste | ~$40 | < $10 | −75% |
| Cache efficiency score | 0.16 | 0.6+ | ✅ target met |

---

## Part 7: What We're Asking Anthropic to Fix

This framework solves the problem at the user level. But platform-level changes from Anthropic would help every subscriber — especially the ones who have no idea the waste is happening.

### Bug Report

**Billing page misrepresents two different types of charges as one**

The Claude console lumps API direct charges and subscription overages into a single display. Users can't tell which is which. The result: users misdiagnose their plan size, disable the wrong settings, and create support tickets for behavior that is actually correct but unexplained.

**Fix:** Show a two-row breakdown — "Subscription (flat fee)" and "API pool (pay-as-you-go)."

---

### Enhancement Requests

**1. Show each user their cache efficiency score**
Display `cache reads ÷ cache saves` as a monthly ratio. Flag anyone below 0.2 with: *"You may be wasting up to 40% of your subscription. See tips."* This single addition would likely save users millions of dollars collectively.

**2. Add billing period reset date to the Admin API**
The reset date is visible in the console UI but missing from the API. Developers building automation tools have to hardcode it — which breaks every month.

**3. Fix the usage limit labels**
"Usage Limit" doesn't tell you what type of limit fired. Labels like "Daily session budget (resets at midnight)" and "Weekly all-models budget (resets Sunday)" are actionable. The current ones are not.

**4. Send alerts before limits are hit**
Let users opt in to a notification at 80% of their weekly or session budget. Right now there's no warning until the limit fires and the session stops.

**5. Open Cowork instruction layers to automation**
Code and Chat instruction layers can be updated programmatically. Cowork requires manual copy-paste in the browser UI. Exposing a simple write API for Cowork instructions would close the gap.

Full technical details: [docs/anthropic-enhancement-requests.md](anthropic-enhancement-requests.md) and [docs/anthropic-bug-report.md](anthropic-bug-report.md)

---

## Quick Start

```bash
# 1. Get the kit
git clone https://github.com/daskuntal75/llm-cost-kit
cd llm-cost-kit

# 2. Install
chmod +x platforms/claude/scripts/update-claude-cost
cp platforms/claude/scripts/* ~/.local/bin/

# 3. Set up your cost tracking file
update-claude-cost --plan YOUR_PLAN_NAME --fee YOUR_MONTHLY_FEE --renews YYYY-MM-DD

# 4. Point to your instruction files
export SKILLS_SOURCE_DIR=~/dev/your-skills-folder   # add to ~/.zshrc

# 5. Deploy the instruction templates
cp platforms/claude/GLOBAL-CLAUDE.md ~/.claude/CLAUDE.md
cp platforms/claude/CLAUDE.md your-project/CLAUDE.md
# Paste platforms/claude/cowork-global-instructions.md into Cowork's global settings

# 6. Wire the hourly background job
# macOS: see platforms/claude/scripts/cumulative-cost-launchagent.sh

# 7. Verify everything is working
regression-test-cost-optimizer --auto
```

---

## Sources

- [GPU Shortages: How the AI Compute Crunch Is Reshaping Infrastructure](https://www.clarifai.com/blog/gpu-shortages-2026) — Clarifai, 2026
- [The GPU Capacity Crisis: Why Enterprises Are Rethinking Infrastructure](https://vexxhost.com/blog/gpu-capacity-crisis-ai-infrastructure-2026/) — Vexxhost, 2026
- [Inside the 2025–2027 Compute Crunch](https://www.bcdvideo.com/blog/inside-the-2025-2027-compute-crunch-what-supply-chain-volatility-really-means-for-you/) — BCD, 2025
- [State of AI 2025: 100 Trillion Token Study](https://openrouter.ai/state-of-ai) — OpenRouter, 2025
- [State of AI: An Empirical 100 Trillion Token Study](https://a16z.com/state-of-ai/) — Andreessen Horowitz, 2025
- [China daily AI token usage exceeds 140 trillion in March](https://technode.com/2026/04/17/china-authority-says-daily-ai-token-usage-exceeds-140-trillion-in-march-up-over-40-vs-end-2025/) — TechNode, April 2026
- [The End of Cheap AI? Anthropic's $30B Growth & Claude Pricing Shift](https://www.madrona.com/price-of-tokenmaxxing-claude-explosive-growth-cost-of-intelligence/) — Madrona, 2026
- [Perspective: AI demand is inflated, and only Anthropic is being realistic](https://www.cnbc.com/2026/04/17/ai-tokens-anthropic-openai-nvidia.html) — CNBC, April 2026
- [Anthropic Changes Pricing to Bill Firms Based on AI Use Amid Compute Crunch](https://www.theinformation.com/articles/anthropic-changes-pricing-bill-firms-based-ai-use-amid-compute-crunch) — The Information, 2026
- [Claude Opus 4.7 Pricing: The Real Cost Story Behind the "Unchanged" Price Tag](https://www.finout.io/blog/claude-opus-4.7-pricing-the-real-cost-story-behind-the-unchanged-price-tag) — Finout, 2026
- [We did the math on AI's energy footprint](https://www.technologyreview.com/2025/05/20/1116327/ai-energy-usage-climate-footprint-big-tech/) — MIT Technology Review, May 2025
- [AI Environment Statistics 2026](https://www.allaboutai.com/resources/ai-statistics/ai-environment/) — AllAboutAI, 2026
- [Why enterprise GPU utilization is stuck at 5%](https://venturebeat.com/infrastructure/fomo-is-why-enterprises-pay-for-gpus-they-dont-use-and-why-prices-keep-climbing) — VentureBeat, 2026

---

## License

CC BY-NC 4.0 — free to use, modify, and share for non-commercial purposes. Attribution required.
See [LICENSE](../LICENSE) for full terms.

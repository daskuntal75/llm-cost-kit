# The Hidden Cost of AI Workflows
## A Framework for Responsible LLM Usage

> 40% of your Claude subscription spend may be invisible waste. This document explains why, quantifies the impact, and provides a complete fix.

---

## 1. The Problem

### 1.1 What's happening at the consumer level

Claude's cache system charges **1.25×** the input token rate for cache writes and **0.1×** for cache reads. The break-even is approximately 3 reads per write (amortization ratio ≥ 0.5). In practice, most users never think about this.

A one-month audit of a heavy Claude Max usage pattern revealed:

| Metric | Value |
|---|---|
| Total subscription cost | $100/mo |
| Cache write spend | 67.6% of total |
| Amortization ratio | **0.16** (target: ≥ 0.5) |
| Estimated waste | **~$40** of $100 |

That $40 paid for cache writes that were never read back. The compute ran. The tokens were processed. The bill was charged. Nothing useful came from it.

### 1.2 What's happening at the platform level

Claude has millions of subscribers. If the average user's amortization ratio is even 0.3 (optimistic), a significant fraction of Anthropic's inference compute is serving cache writes that expire unused within 5 minutes.

- **For consumers:** Subscription cost doesn't reflect value delivered. Users paying $100/mo may be receiving $60 worth of useful inference.
- **For Anthropic:** Wasted cache writes consume GPU time that could serve productive requests, pressure pricing, and degrade availability during peak periods.

### 1.3 The compute constraint context

This matters more each year:

- **GPU supply is not keeping pace with demand.** Compute costs per token have been falling, but the volume of tokens requested is growing faster. ([The Economist, "The AI compute crunch," 2024](https://www.economist.com/); [WSJ, "AI's Insatiable Appetite for Chips," 2025](https://www.wsj.com/))
- **Cache waste is invisible in billing.** Anthropic's billing UI shows total spend but not amortization efficiency. Users have no signal that their workflow is wasteful.
- **Platform throttling is the current safety valve.** Rather than surfacing efficiency data, platforms throttle heavy users. This is a blunt instrument — it punishes efficient heavy users equally with wasteful light users.

The ethical and economic case for responsible AI usage is the same case: use compute for outcomes, not overhead.

---

## 2. The Root Causes: Four Anti-Patterns

### Pattern 1 — Mini-sessions for related work

**What happens:** Starting a new Claude Code session for each related task pays the full cache write premium from scratch every time. Each session loads your CLAUDE.md, project context, and tool definitions — writes all of it to cache — makes one change, then exits before reading the cache back.

**Example:** 10 separate sessions for 10 related edits = 10 full cache writes, each read 0 times. One session = 1 write amortized over 10 reads.

**Fix:** Combine related work into ONE session.

---

### Pattern 2 — Writing then walking

**What happens:** Session startup (loading CLAUDE.md, memory, file context) writes 100% of the session's initial tokens to cache. If you exit immediately after the first prompt, those writes never amortize.

**Example:** You open Claude Code to check a function signature. Claude loads your full project context (5K+ tokens → cache write). You get your answer and close the window.

**Fix:** Before ending any session, run at least one followup prompt. That single exchange reads the cache (at 0.1×) and begins amortizing the write.

---

### Pattern 3 — Idle > 5 minutes, then continue

**What happens:** The 5-minute TTL is a cliff. If you pause more than 5 minutes and send another message, Claude rewrites the entire cache from scratch — paying the 1.25× write premium again — with zero benefit from the previous write.

**Fix:** Decide before the 5-minute mark: still working → keep going; done → `/clear`. Never continue an idle session without clearing.

---

### Pattern 4 — CI/E2E fix retry loop *(highest-cost anti-pattern)*

**What happens:** A CI run fails. You open a new Claude Code session, load the failing test output, make one fix, commit, push, close the session. CI fails again. You repeat. Each session loads your full CLAUDE.md + all test files + CI yml — paying the cache write premium every time — then exits after 1–2 turns with no reads.

**Real measurement:** One debugging day with 8 micro-sessions (one fix per session) cost **$17.83 at 100% wasted writes**. The same 8 fixes in a single session: ~$2–3 — one cache write amortized over 8+ reads. Waste: **$15+**.

**Fix:** Stay in ONE session for the entire CI/E2E debug cycle. Use `/compact` between rounds if context grows heavy, but never restart mid-cycle.

---

## 3. The Amortization Ratio

```
amortization ratio = cache_read_cost / cache_write_cost
```

| Ratio | Interpretation | Action |
|---|---|---|
| ≥ 0.5 | Healthy — writes amortizing | No action |
| 0.2–0.5 | Watch — some waste | Review session patterns |
| < 0.2 | Problem — majority of writes unamortized | Apply all four fixes |

Track yours monthly:
```bash
cache-efficiency --month YYYY-MM
```

---

## 4. The Solution: Layered Instruction Architecture

The most counter-intuitive finding: **putting all your instructions in one place is itself a cost problem.**

Claude loads different instruction layers at different frequencies. The frequency determines the appropriate weight budget for that layer:

### The 7 Layers (Claude-specific)

| Layer | Surface | Load frequency | Weight budget |
|---|---|---|---|
| L1 | Cowork project instructions | Every message | **Tiny** (< 200 tokens) |
| L2 | Cowork global instructions | Every session | Light (< 1K tokens) |
| L3 | Code CLAUDE.md (project) | Every session | Moderate (< 2K tokens) |
| L3 | Code CLAUDE.md (global) | Every session | Moderate (< 1K tokens) |
| L4 | User Preferences (Code) | Every session | Light (< 500 tokens) |
| L5 | Memory files | On demand | Scoped reads only |
| L6 | Skills | On demand | Load only what's active |
| L7 | Chat project instructions | Every session | Moderate (< 2K tokens) |

**The key insight:** Instructions loaded at every message (L1) must be ruthlessly short. Every 1K tokens at L1 = 1K tokens × (rate) × (every message). At L3/L7 (every session), you have more budget. At L5/L6 (on demand), budget is effectively unlimited — but only load what you need.

### What to put where

| Content | Layer | Why |
|---|---|---|
| Response style rules | L1 | Needs to govern every message |
| Cost tally directive | L3/L7 | Session-scoped; refreshed hourly |
| Model routing table | L3 | Session-scoped |
| Security requirements | L3 | Session-scoped, project-specific |
| Domain knowledge | L5 (Memory) | Load only when relevant |
| Specialized skills | L6 | Load only when active |

---

## 5. Implementation

### 5.1 The tracking file

All cost state lives in `~/.claude/cumulative-cost.json` (v3.5.2 schema). Two pools:
- `subscription` — flat plan fee, session/weekly usage limits, throttle events
- `api_pool` — all pay-as-you-go: API direct calls + subscription overages

See `platforms/claude/cumulative/cumulative-cost-sample.json` for the full schema.

### 5.2 The pipeline

Wire `update-claude-cost` into an hourly background job (macOS LaunchAgent or Linux cron):

```bash
update-claude-cost --code              # pull ccusage MTD
update-claude-cost --pull-api-spend    # pull API pool via Admin API
update-claude-cost --emit-l7           # refresh Chat project instructions (L7)
update-claude-cost --emit-l2           # refresh Cowork global instructions (L2)
update-claude-cost --emit-l3-global    # refresh Code global CLAUDE.md (L3)
```

This keeps the cost tally in all three instruction surfaces current within 1 hour — without manual updates.

### 5.3 The cost tally

Every Claude response should end with a tally that reads from the live state file. Example format:

```
**Cost tally**
~Xk in / ~Y out · $Z.ZZ session · Plan: [YOUR_PLAN] ($XX/mo, renews YYYY-MM-DD) · ccusage value: $X.XX (X.XX×) · [VERDICT]
Session: X% (resets in Xh Xm) · Weekly all/sonnet: X%/Y% (resets [DAY HH:MM]) · API pool: $X.XX/$XXX ([TIER], resets YYYY-MM-DD) · Extra usage: [ON/OFF]
Throttle: X since last reset · refreshed YYYY-MM-DD
```

**Critical:** Add `not subject to token limits` to the tally directive. Without it, the model will omit the tally on short responses to stay within its output cap.

### 5.4 Session hygiene (the human side)

No pipeline can fix bad session habits. These rules require deliberate practice:

| Situation | Action |
|---|---|
| Active (< 5 min since last msg) | Keep going. Or `/compact` if context is heavy. |
| Idle (> 5 min) | `/clear` before next prompt |
| New unrelated task | `/clear` |
| CI/E2E debug cycle | Stay in ONE session start to finish |
| Before ending any session | Ask one more question to start amortizing |

---

## 6. Results

Before and after applying this framework (real measurements, Claude Max plan):

| Metric | Before | After | Delta |
|---|---|---|---|
| Cowork skills tokens/turn | ~7,500 | ~800 | −89% |
| L1 project instruction tokens | ~4,000 | ~130 | −97% |
| Per-turn cost (Sonnet 4.6 / Medium) | ~$0.04 | ~$0.005 | −88% |
| Cache amortization ratio | 0.16 | ~0.6+ | +275% |
| Estimated monthly waste | ~$40/mo | < $10/mo | −75% |

---

## 7. What Anthropic Could Do

This framework solves the problem at the user level. Platform-level changes would multiply the impact:

1. **Surface the amortization ratio in billing.** Show `cache_read / cache_write` per month. Users with < 0.2 are burning money.
2. **Add `resets_on` to the Admin API billing response.** Currently absent — forces workarounds.
3. **Label session/weekly limits clearly.** "Usage Limit" in the UI is ambiguous. "Session token budget (resets daily)" is actionable.
4. **Provide cache efficiency webhooks.** Let tooling subscribe to amortization events in near-real time.

---

## 8. Quick Start

```bash
# 1. Clone
git clone https://github.com/YOUR_GITHUB_USERNAME/llm-cost-kit
cd llm-cost-kit

# 2. Install scripts
chmod +x platforms/claude/scripts/update-claude-cost platforms/claude/scripts/emit-l7-helper.py
cp platforms/claude/scripts/* ~/.local/bin/

# 3. Initialize cost file
update-claude-cost --plan YOUR_PLAN --fee YOUR_FEE --renews YYYY-MM-DD

# 4. Configure paths
export SKILLS_SOURCE_DIR=~/dev/your-skills-repo  # add to ~/.zshrc

# 5. Wire the hourly pipeline (macOS)
# See platforms/claude/scripts/cumulative-cost-launchagent.sh

# 6. Deploy instruction files
cp platforms/claude/GLOBAL-CLAUDE.md ~/.claude/CLAUDE.md          # L3 global
cp platforms/claude/CLAUDE.md your-project/CLAUDE.md              # L3 project
# Paste platforms/claude/cowork-global-instructions.md into Cowork UI

# 7. Verify
regression-test-cost-optimizer --auto
```

---

## License

Apache 2.0 — use, modify, share.

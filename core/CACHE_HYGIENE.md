# Cache Hygiene — The Four Anti-Patterns

> Why $40 of $100 was wasted in April 2026, and the four rules that prevent it.

Claude Code caches conversation context with a **5-minute TTL**. Cache writes cost **1.25× the input token rate**. Cache reads cost **0.1×**. Break-even is approximately **3 reads per write** (amortization ratio ≥ 0.5).

A real-world audit of one month's Claude Code usage revealed:
- 67.6% of spend on cache writes
- Amortization ratio: **0.16** (target ≥ 0.5)
- Estimated wasted writes: **~$40 of $100**

The waste traced to four workflow patterns.

---

## Pattern 1 — Mini-sessions for related work

**What happens:** Starting a new Claude Code session for each related task pays the full cache write premium from scratch every time. Each session loads your CLAUDE.md, project context, and tool definitions — writes all of it to cache — makes one change, then exits before reading the cache back.

**Fix:** Combine related work into ONE session. The cache write amortizes across every prompt in the session. Ten prompts in one session = one write amortized over ten reads. Ten separate sessions = ten writes, each read zero times.

---

## Pattern 2 — Writing then walking

**What happens:** Session startup (loading CLAUDE.md, memory, file context) writes 100% of the session's initial tokens to cache. If you exit immediately after the first prompt, those writes never amortize.

**Example:** You open Claude Code to check a function signature. Claude loads your full project context (5K tokens → cache write). You get your answer and close the window. That cache write is now a sunk cost — no reads, no amortization.

**Fix:** Before ending any session, run at least one followup prompt. That single additional exchange reads the cache (at 0.1×) and recovers the write investment. If you genuinely have nothing else to ask, use `/clear` before the second prompt to reset — but usually there's something.

---

## Pattern 3 — Idle > 5 minutes, then continue

**What happens:** The 5-minute TTL is a cliff. If you pause for more than 5 minutes and then send another message, Claude rewrites the entire cache from scratch — paying the 1.25× write premium again — with zero benefit from the previous write.

**Fix:** Decide before the 5-minute mark:
- Still working? → Keep going. One prompt within 5 min keeps the cache warm.
- Done for now? → Run `/clear` before stepping away. A fresh start costs the same as a re-write but at least you're setting context intentionally.
- Resuming after a break? → Always use `/clear`. Never continue an idle session.

---

## Pattern 4 — CI/E2E fix retry loop *(highest-cost anti-pattern)*

**What happens:** A CI run fails. You open a new Claude Code session, load the failing test output, make one fix, commit, push, close the session. CI fails again. You repeat. Each session loads your full CLAUDE.md + all test files + CI yml — paying the cache write premium every time — then exits after 1–2 turns with no reads.

**Real example:** One debugging day with 8 micro-sessions (one fix per session) cost **$17.83 at 100% wasted writes**. The same 8 fixes in a single session would have cost ~$2–3 — one cache write amortized over 8+ reads.

**Fix:** Stay in one session for the entire CI/E2E debug cycle. Use `/compact` between rounds if the context grows heavy, but never restart mid-cycle. When a test fails, fix it in the same session, push, and wait for CI — don't close and reopen.

---

## The amortization ratio

```
amortization ratio = cache_read_cost / cache_write_cost
```

| Ratio | Interpretation |
|---|---|
| ≥ 0.5 | Healthy — writes are amortizing |
| 0.2–0.5 | Watch — some waste, optimize session patterns |
| < 0.2 | Problem — majority of writes are unamortized |

Use `cache-efficiency --month YYYY-MM` to compute your ratio from `ccusage` data.

---

## Where to apply these rules

The four hygiene rules should appear in all Claude instruction layers where sessions occur:

| Layer | Why |
|---|---|
| `~/.claude/CLAUDE.md` (global) | Applies to all Code sessions regardless of project |
| Project `CLAUDE.md` | Reinforces in project context |
| Cowork Global Instructions | Applies to Cowork sessions |

The `emit-l7-helper.py` script distributes the rules to Chat project instructions automatically as part of the hourly pipeline.

---

## API direct calls (1-hour TTL)

For production API calls (when your app calls Anthropic directly), the 5-minute TTL anti-patterns above apply to the `ephemeral` cache type. Use 1-hour TTL for stable content:

```json
{
  "type": "ephemeral",
  "ttl": "1h"
}
```

Apply 1h TTL to: system prompts, project context blocks, tool definitions.
Apply 5m TTL to: per-request user content that changes each call.

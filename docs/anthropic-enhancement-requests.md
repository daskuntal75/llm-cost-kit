# Anthropic Enhancement Requests

Documented gaps discovered while building the v3.5.2 cost tracking framework. Submitted as actionable feedback.

---

## #1 — Billing UI misrepresents three pools as two

**Surface:** console.anthropic.com / Billing

**What the UI shows:**
- "Usage" section with a single spend bar
- Credit balance + auto-reload settings

**What it omits:**
- The distinction between subscription extra_usage (charged at API rates when enabled) and API direct calls (always at API rates)
- `resets_on` date for the API pool billing period
- Cache amortization efficiency (writes vs. reads)

**Impact:** Users on Max plan with `extra_usage_enabled: false` see API charges and assume they're subscription overages. They're not — they're API direct calls. The confusion leads to misdiagnosis of plan-sizing decisions.

**Request:** Add a two-pool breakdown to the billing page:
- Row 1: Subscription flat fee — current plan, monthly cap, renewal date
- Row 2: API pool — current spend, customer limit, tier, resets_on
- Optional: cache amortization ratio (cache_read_cost / cache_write_cost)

---

## #2 — Admin API billing response missing `resets_on`

**Endpoint:** `GET /v1/organizations/{org_id}/usage`

**Current response** includes current spend but not the billing period reset date. The reset date is critical for:
- Computing % of billing period elapsed (to normalize spend)
- Alerting before the period closes

**Request:** Add `resets_on: "YYYY-MM-DD"` to the billing response. This date is shown in the console UI; exposing it via API would remove the need for users to hardcode it.

---

## #3 — Ambiguous limit labels in UI and API responses

**Examples:**
- "Usage Limit" — is this session-level, weekly, or monthly?
- Rate limit errors don't distinguish between RPM, daily token budget, and weekly model budget

**Impact:** Users hitting throttles can't diagnose which limit fired. Building tracking tooling requires guessing the limit type from context.

**Request:** Standardize limit labels:
- `session_token_budget` (resets daily)
- `weekly_all_models_budget` (resets weekly)
- `weekly_sonnet_budget` (resets weekly, Sonnet-specific)
- `api_rate_limit` (RPM/TPM)

Expose these labels in error responses and the console UI.

---

## #4 — No cache amortization visibility

**Context:** Claude's cache system charges 1.25× for writes and 0.1× for reads. A user whose amortization ratio (reads/writes) is < 0.2 is wasting ~40% of their spend on cache writes that expire unused.

**Current state:** Billing shows total cache write cost and total cache read cost, but:
- No ratio is surfaced
- No per-session breakdown is available
- No alert fires when amortization drops below a threshold

**Request:** Add `cache_amortization_ratio` to the monthly billing summary. Flag accounts with ratio < 0.2 in the console UI with a "workflow efficiency" nudge.

---

## #5 — No webhooks for usage events

**Current state:** The only way to track usage is to poll the Admin API or read from `ccusage`. There are no webhooks for:
- Session start/end
- Throttle events
- Weekly budget approaching (e.g., 80%)
- API pool approaching customer limit

**Request:** Add webhooks for at least throttle events and weekly budget thresholds. This would enable real-time alerting without polling.

---

## #6 — Cowork project instructions not accessible via API

**Context:** The 7-layer instruction hierarchy (L1–L7) has a gap: Cowork project and global instructions are only editable via the Cowork UI. There is no API to read or write them.

**Impact:** Automated pipelines (e.g., hourly cost tally refresh) can update L3 (Code CLAUDE.md), L5 (memory files), and L7 (Chat project instructions) programmatically — but L1 and L2 (Cowork layers) require manual copy-paste.

**Request:** Expose a read/write API for Cowork project and global instruction text. Even a simple PUT with the full instruction text would enable automation parity across all 7 layers.

---

*These requests are based on real workflow gaps discovered while building open-source tooling for Claude cost management. The full framework is at [llm-cost-kit](https://github.com/daskuntal75/llm-cost-kit).*

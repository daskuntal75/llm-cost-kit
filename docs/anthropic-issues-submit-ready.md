# Anthropic Issues — Submit-Ready Format

Submission guide and formatted issues for billing, limits, and usage telemetry gaps in Claude desktop and terminal tooling.

---

## Where to Submit Each Issue

| Issue | Best channel | Priority routing |
|---|---|---|
| Bug: billing UI misrepresents charges | Support ticket + Twitter/X @AnthropicAI | Lead with "billing data integrity" — routes to engineering |
| Enhancement: cache efficiency score | claude.ai feedback form + Discord #feature-requests | Frame as "billing transparency" |
| Enhancement: `resets_on` in Admin API | GitHub `anthropics/anthropic-sdk-python` | Tag: `billing`, `admin-api` |
| Enhancement: standardize limit labels | claude.ai feedback form | Frame as "usage limit clarity" |
| Enhancement: pre-limit alerts/webhooks | GitHub `anthropics/anthropic-sdk-python` | Tag: `feature-request`, `telemetry` |
| Enhancement: Cowork instruction API | claude.ai feedback form + Discord | Frame as "automation parity" |

**Practical tip:** Submit the billing bug as a support ticket first (fastest path to engineering), then post the GitHub issues. Bundle the 5 enhancements into a single Discord post with a link to the GitHub issues — one coherent ask is more actionable than five scattered ones.

---

## Issue 1 — BUG: Billing UI misrepresents two charge sources as one

**Submit to:** claude.ai → Help → Contact Support
**Subject line:** `[Billing Bug] Console UI combines API direct charges and subscription overages — cannot distinguish charge sources`

---

**Bug Report**

**Product:** claude.ai Console — Billing page
**Plan:** Claude Max ($100/mo)
**Severity:** Medium — causes financial misdiagnosis; no data corruption

**Summary**

The billing console combines two fundamentally different charge types into a single "Usage" display, making it impossible for users to determine what they are actually being billed for or why.

**Charge types that are conflated:**

| Charge type | What it is | When it applies |
|---|---|---|
| API direct calls | Pay-as-you-go charges from external applications calling the Anthropic API | Always, when your app calls the API |
| Subscription extra usage | Overages above the plan's included usage, billed at API rates | Only when `extra_usage_enabled: true` |

**Steps to reproduce**

1. Have an active Claude Max subscription with `extra_usage_enabled: false`
2. Run API calls from an external application (e.g., a production web app using the Anthropic SDK)
3. Navigate to console.anthropic.com → Billing
4. Observe: both charge types appear under the same "Usage" section with no source label

**Expected behavior**

The billing page distinguishes charge sources:
- Row 1: `Subscription (flat fee)` — $X/mo, plan name, renewal date
- Row 2: `API pool (pay-as-you-go)` — current spend, customer cap, tier, reset date, source breakdown

**Actual behavior**

All charges appear in one undifferentiated block. Users on Max plan with `extra_usage_enabled: false` see API charges and incorrectly assume they are subscription overages, leading to:
- Misdiagnosis of plan sizing ("I'm over my plan limit" when they're not)
- Incorrect toggling of `extra_usage_enabled`
- Support tickets for correct but unexplained behavior

**Evidence**

Built custom tooling ([github.com/daskuntal75/llm-cost-kit](https://github.com/daskuntal75/llm-cost-kit)) to track both pools separately via the Admin API. The two pools behave differently and need separate display.

**Proposed fix (Option A — minimal effort)**

Add a charge source label to each line item:
- "Claude.ai surfaces (subscription plan)"
- "API direct calls (your applications)"

**Proposed fix (Option B — correct solution)**

Two-row billing summary:
```
Subscription:  max-5x · $100/mo · Renews 2026-06-21 · Extra usage: OFF
API pool:      $0.82 of $150 customer cap · Tier 2 · Resets 2026-06-01
```

---

## Issue 2 — ENHANCEMENT: Show cache efficiency score in billing dashboard

**Submit to:** claude.ai → Help → Share Feedback
**GitHub label suggestion:** `enhancement`, `billing`, `cache`

---

**Feature Request**

**Title:** `[Enhancement] Display monthly cache amortization ratio in billing dashboard`

**Problem**

Claude's caching system charges 1.25× the input rate for cache writes and 0.1× for cache reads. The break-even requires approximately 3 reads per write (ratio ≥ 0.5).

A one-month audit of a heavy Max subscription found:
- Cache write spend: 67.6% of total bill
- Cache amortization ratio: **0.16** (target ≥ 0.5)
- Estimated waste from unamortized writes: **~$40 of $100**

The billing UI currently shows the dollar amounts for cache writes and cache reads separately — but does not compute or surface the ratio. Users have no signal that their workflow is wasteful.

**Proposed solution**

Add a `Cache efficiency` metric to the monthly billing summary:

```
Cache efficiency:  0.16  ⚠ Low — you may be wasting ~40% on unused saves
                         See: 4 habits that reduce cache waste [link]
```

Flag thresholds:
- ≥ 0.5 → No indicator (healthy)
- 0.2–0.5 → Yellow indicator + link to tips
- < 0.2 → Orange indicator + "You may be wasting up to 40% of your subscription"

**Impact**

Most users don't know the cache pricing model exists. Surfacing efficiency data — even as a single number — would save users significant money and reduce compute waste at scale. Given Claude has millions of subscribers, even moving the average ratio from 0.2 to 0.4 would reclaim a material fraction of total inference compute.

**Reference**

Full analysis and open-source tooling: [github.com/daskuntal75/llm-cost-kit/blob/main/docs/responsible-ai-cost-framework.md](https://github.com/daskuntal75/llm-cost-kit/blob/main/docs/responsible-ai-cost-framework.md)

---

## Issue 3 — ENHANCEMENT: Add `resets_on` to Admin API billing response

**Submit to:** GitHub — `anthropics/anthropic-sdk-python` → New Issue
**Labels:** `enhancement`, `admin-api`, `billing`

---

**Title:** `[Enhancement] Add resets_on field to /v1/organizations/{org_id}/usage response`

**Problem**

The Admin API billing endpoint returns current spend and usage metrics but does not include the billing period reset date (`resets_on`). This date is visible in the console UI but inaccessible via API.

**Impact on developers**

Any automation that computes normalized spend (e.g., "% of billing period elapsed") or schedules budget alerts must hardcode the reset date — which breaks at the start of every new billing period and requires manual intervention to update.

**Current workaround**

```python
# Forced to hardcode — breaks monthly
RESET_DATE = "2026-06-01"
days_elapsed = (today - date.fromisoformat(RESET_DATE)).days
days_total = 30
normalized_spend = current_spend / (days_elapsed / days_total)
```

**Proposed solution**

Add `resets_on` (ISO date string) to the usage response:

```json
{
  "current_spend": 0.82,
  "customer_limit": 150.00,
  "tier_name": "Tier 2",
  "resets_on": "2026-06-01"
}
```

**Effort estimate**

This field is already computed and displayed in the console UI. Exposing it via the API appears to be a one-line addition to the serializer.

---

## Issue 4 — ENHANCEMENT: Standardize usage limit labels across UI and API errors

**Submit to:** claude.ai → Help → Share Feedback
**GitHub label suggestion:** `enhancement`, `ux`, `limits`

---

**Title:** `[Enhancement] Replace ambiguous "Usage Limit" labels with specific limit type identifiers`

**Problem**

Claude surfaces multiple independent usage limits (session-level, weekly all-models, weekly Sonnet-specific, API rate limits) but labels all of them identically as "Usage Limit" in the UI and error responses. When a limit fires, users cannot determine:

1. Which limit was hit
2. When it resets
3. What action to take

**Current behavior (confusing)**

```
You've reached your usage limit. Please try again later.
```

**Proposed behavior (actionable)**

```
Daily session budget reached (resets in 4h 22m)
```
or
```
Weekly all-models budget at 100% (resets Sunday 10:00)
```
or
```
API rate limit: 60 requests/min exceeded (resets in 43 seconds)
```

**Proposed label taxonomy**

| Limit type | Proposed label |
|---|---|
| Session daily budget | `session_daily_budget` |
| Weekly all-models budget | `weekly_all_models_budget` |
| Weekly Sonnet budget | `weekly_sonnet_budget` |
| API requests per minute | `api_rpm_limit` |
| API tokens per minute | `api_tpm_limit` |

Apply these labels in: console UI, in-app error messages, API error response `type` field, and rate limit headers.

---

## Issue 5 — ENHANCEMENT: Pre-limit alerts and webhooks for session/weekly budgets

**Submit to:** GitHub — `anthropics/anthropic-sdk-python` → New Issue
**Labels:** `enhancement`, `telemetry`, `webhooks`

---

**Title:** `[Enhancement] Add opt-in usage alerts at configurable thresholds (e.g. 80% of weekly budget)`

**Problem**

Claude currently provides no warning before a usage limit is reached. Sessions simply stop when a budget is exhausted — with no advance notice. There is also no programmatic way to subscribe to limit events.

**Use cases blocked**

1. A user mid-way through a long debugging session hits the weekly limit unexpectedly — work is lost, session state is gone
2. A developer building on the API has no way to alert their users before rate limits degrade service
3. Automation tooling cannot self-throttle based on budget proximity

**Proposed solution — two tiers**

**Tier 1 (UI only, low effort):** Email/push notification when session or weekly budget reaches 80%. Opt-in in account settings.

**Tier 2 (API, higher effort):** Webhook or Server-Sent Events endpoint that fires on budget threshold events:

```json
{
  "event": "budget_threshold",
  "limit_type": "weekly_all_models_budget",
  "threshold_pct": 80,
  "current_pct": 81,
  "resets_at": "2026-05-11T10:00:00Z"
}
```

**Minimum viable version**

An `X-Usage-Budget-Remaining-Pct` response header on every API call would let developers build their own alerts without requiring Anthropic to implement webhooks.

---

## Issue 6 — ENHANCEMENT: Expose Cowork global and project instruction layers via API

**Submit to:** claude.ai → Help → Share Feedback + Discord #feature-requests
**GitHub label suggestion:** `enhancement`, `api`, `cowork`

---

**Title:** `[Enhancement] Add read/write API for Cowork global and project instruction layers`

**Problem**

Claude's instruction system has 7 layers. Of those, 5 can be updated programmatically:

| Layer | Auto-updatable? |
|---|---|
| L3 Code CLAUDE.md (global + project) | ✅ File on disk |
| L5 Memory files | ✅ Files on disk |
| L7 Chat project instructions | ✅ Via API (read) |

But the two Cowork layers require manual copy-paste in the browser UI:

| Layer | Auto-updatable? |
|---|---|
| L1 Cowork project instructions | ❌ UI only |
| L2 Cowork global instructions | ❌ UI only |

**Impact**

Any automation that keeps instruction content current (e.g., cost tally refresh, plan details, session limits) must manually update Cowork layers. This creates a two-tier system: Code and Chat instructions stay accurate automatically; Cowork instructions drift.

Real example: an hourly pipeline successfully refreshes Code CLAUDE.md and Chat project instructions with current cost data — but Cowork global instructions must be copy-pasted manually into the browser.

**Proposed solution**

A simple REST endpoint for Cowork instruction CRUD:

```
GET  /v1/cowork/instructions/global
PUT  /v1/cowork/instructions/global   { "content": "..." }
GET  /v1/cowork/projects/{id}/instructions
PUT  /v1/cowork/projects/{id}/instructions   { "content": "..." }
```

**Minimum viable version**

Read-only access (GET) would at least enable validation tooling. Full read/write would enable automation parity across all 7 layers.

---

## Bundled Discord / Community Post Template

Use this when posting to Anthropic's Discord `#feature-requests` channel:

---

**Subject:** 5 billing/limits enhancements + 1 bug — data and formatted issues attached

I've been running detailed cost tracking on Claude Max for several months and found a cluster of related gaps in billing transparency and usage telemetry. Formatted GitHub-style issues with full reproduction steps and proposed solutions are at:

👉 github.com/daskuntal75/llm-cost-kit/blob/main/docs/anthropic-issues-submit-ready.md

**TL;DR of the 6 issues:**
1. 🔧 **Bug:** Billing UI conflates API direct charges with subscription overages — users can't tell what they're paying for
2. 📊 Show monthly cache efficiency score — 40% of one Max subscription was going to unused saves
3. 🔌 Add `resets_on` to Admin API — currently forces devs to hardcode billing reset dates
4. 🏷️ Clarify limit labels — "Usage Limit" is unactionable; "Daily session budget (resets in 4h)" is
5. 🔔 Pre-limit alerts — sessions just stop with no warning; an 80% threshold notification would help
6. 🖊️ Cowork instruction API — only layer in the 7-layer system that can't be updated programmatically

All are well-scoped, low-risk changes. The billing bug especially affects enterprise users trying to reconcile subscription vs. API charges. Happy to provide additional data or jump on a call.

---

*Full open-source cost tracking kit: github.com/daskuntal75/llm-cost-kit (CC BY-NC 4.0)*

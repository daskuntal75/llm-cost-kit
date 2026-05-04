# Bug Report: Console Billing UI Misrepresents Charge Sources

**Product:** Claude.ai Console — Billing page
**Severity:** Medium (financial confusion; no data loss)
**Discovered:** April 2026

---

## Summary

The console billing UI combines two distinct charge sources into a single display, making it impossible for users to distinguish:
1. **API direct calls** — always billed at pay-as-you-go rates via the API pool
2. **Subscription extra usage** — billed at API rates only when `extra_usage_enabled: true`

Users on Max plan with `extra_usage_enabled: false` see charges in the "API Usage" section and incorrectly interpret them as subscription overages. They're API direct calls from external projects, not plan overages.

---

## Steps to Reproduce

1. Have a Claude Max subscription with `extra_usage_enabled: false`
2. Run API calls from an external project (e.g., a production web app)
3. Navigate to console.anthropic.com → Billing
4. Observe "API Usage" charges in the billing summary

**Expected:** The UI distinguishes "API direct calls (your.app)" from "Subscription extra usage (Claude.ai surfaces)"

**Actual:** Both appear under the same "Usage" section with no source label. Users assume all charges are plan overages.

---

## Impact

- Users misdiagnose plan-sizing decisions (thinking they're "above plan limits" when they're running direct API calls)
- Users disable `extra_usage_enabled` thinking it will stop all API charges — it doesn't stop direct API calls
- Support tickets created for behavior that is correct but unexplained

---

## Proposed Fix

**Option A (minimal):** Add a charge source label to each line item:
- "Claude.ai surfaces (subscription)" 
- "API direct calls ([your project name])"

**Option B (structural):** Two-row billing breakdown:
- Row 1: `Subscription` — flat fee, current plan, renewal date
- Row 2: `API pool` — current spend, customer limit, tier, reset date, source breakdown

**Option C (future):** Full usage dashboard with per-project breakdown, cache amortization ratio, and efficiency nudges.

Option A has the lowest implementation cost and resolves the core confusion. Option B is what most users building on the platform actually need.

---

## Workaround

Track the API pool separately using the Admin API:
```bash
GET /v1/organizations/{org_id}/usage
# Returns current_spend — but not resets_on (see Enhancement Request #2)
```

Users building cost tracking tooling have to hardcode the reset date because the API doesn't expose it.

---

*Reported by a Claude Max user building open-source cost tracking tooling. Full context at [llm-cost-kit](https://github.com/daskuntal75/llm-cost-kit).*

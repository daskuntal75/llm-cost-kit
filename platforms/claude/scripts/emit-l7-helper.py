#!/usr/bin/env python3
"""
v3.5.2 emit-l7-helper.py
Two-pool schema: subscription + api_pool. Drops separate extra_usage block.

Emits current cost state into Claude instruction files:
  L7: Chat project instruction files (one .md per project)
  L2: Cowork global instructions (--l2 <path>)
  L3-global: ~/.claude/CLAUDE.md (--l3-global <path>)

Usage:
  emit-l7-helper.py <cost-file> <l7-dir>               # L7 only
  emit-l7-helper.py <cost-file> - --l2 <l2-path>        # L2 only
  emit-l7-helper.py <cost-file> - --l3-global <path>    # L3-global only
  emit-l7-helper.py <cost-file> <l7-dir> --l2 <l2-path> # L7 + L2

Called by update-claude-cost --emit-l7 / --emit-l2 / --emit-l3-global.
"""
import json
import sys
import re
import os
from datetime import date, datetime, timezone

# --- Arg parsing (keep positional compat; add optional --l2 / --l3-global) ---
args = sys.argv[1:]
l2_path = None
if "--l2" in args:
    idx = args.index("--l2")
    l2_path = args[idx + 1]
    args = args[:idx] + args[idx + 2:]

l3_global_path = None
if "--l3-global" in args:
    idx = args.index("--l3-global")
    l3_global_path = args[idx + 1]
    args = args[:idx] + args[idx + 2:]

if len(args) < 2:
    print("Usage: emit-l7-helper.py <cost-file> <l7-dir> [--l2 <l2-path>]", file=sys.stderr)
    sys.exit(1)

cost_file = args[0]
l7_dir = args[1]  # pass "-" to skip L7

with open(cost_file) as f:
    data = json.load(f)

sub = data["subscription"]
plan = sub["plan"]
fee = sub["monthly_fee_usd"]
renewal = sub.get("renewal_date") or "?"
extra_enabled = sub.get("extra_usage_enabled", False)

session_pct = sub["session_limit"]["percent_used"]
session_resets = sub["session_limit"].get("resets_at")
weekly_all = sub["weekly_all_models"]["percent_used"]
weekly_sonnet = sub["weekly_sonnet_only"]["percent_used"]
weekly_resets = sub["weekly_all_models"].get("resets_at") or "?"

throttle_mtd = sub["throttle_hits_mtd"]
since_reset = sub.get("throttle_hits_since_last_reset", 0)
breakdown = sub.get("throttle_breakdown_since_reset", {"usage_limit": 0, "tool_limit": 0})
next_reset = sub.get("next_reset_at")
window_started = sub.get("window_started_at")

api = data["api_pool"]
api_spend = api["current_spend"]
api_limit = api["customer_limit"]
api_tier = api.get("tier_name") or "?"
api_ceiling = api.get("tier_ceiling") or 0
api_resets = api.get("resets_on") or "?"
credit_balance = api.get("credit_balance") or 0
auto_reload_threshold = api.get("auto_reload_threshold") or 0
auto_reload_amount = api.get("auto_reload_amount") or 0

ccusage_mtd = data["value_signal"]["ccusage_mtd"]
ratio = data["value_signal"]["ratio_to_plan_fee"]
verdict = data["value_signal"]["verdict"]

today = date.today().isoformat()


def fmt_time(iso_str):
    if not iso_str: return "?"
    try:
        return datetime.fromisoformat(iso_str.replace("Z", "+00:00")).astimezone().strftime("%H:%M")
    except Exception:
        return iso_str[:16]


def hours_until(iso_str):
    if not iso_str: return "?"
    try:
        delta_min = max(0, int((datetime.fromisoformat(iso_str.replace("Z", "+00:00")) - datetime.now(timezone.utc)).total_seconds() / 60))
        if delta_min < 60: return f"{delta_min}m"
        h, m = delta_min // 60, delta_min % 60
        return f"{h}h {m}m" if m > 0 else f"{h}h"
    except Exception: return "?"


def short_date(iso_str):
    if not iso_str: return "?"
    try:
        return datetime.fromisoformat(iso_str.replace("Z", "+00:00")).strftime("%m-%d")
    except Exception:
        return iso_str[:10]


if since_reset == 0:
    if next_reset:
        throttle_phrase = f"Throttle: 0 since last reset (next reset {fmt_time(next_reset)}, in {hours_until(next_reset)})"
    else:
        throttle_phrase = "Throttle: 0 since last reset"
else:
    parts = []
    if breakdown.get("usage_limit", 0) > 0: parts.append(f"{breakdown['usage_limit']} usage")
    if breakdown.get("tool_limit", 0) > 0: parts.append(f"{breakdown['tool_limit']} tool")
    breakdown_str = ", ".join(parts)
    throttle_phrase = (
        f"Throttle: {since_reset} since last reset at {fmt_time(window_started)} "
        f"({breakdown_str} · next reset {fmt_time(next_reset)}, in {hours_until(next_reset)})"
    )

session_resets_str = f" (resets in {hours_until(session_resets)})" if session_resets else ""
weekly_resets_str = short_date(weekly_resets) if weekly_resets and "T" in str(weekly_resets) else (weekly_resets[:12] if weekly_resets and weekly_resets != "?" else "?")
extra_str = "ON" if extra_enabled else "OFF"

line1 = (
    f"~Xk in / ~Y out · $Z.ZZ session · "
    f"Plan: {plan} (${fee}/mo, renews {renewal}) · "
    f"ccusage value: ${ccusage_mtd:.2f} ({ratio}×) · {verdict}"
)
line2 = (
    f"Session: {session_pct}%{session_resets_str} · "
    f"Weekly all/sonnet: {weekly_all}%/{weekly_sonnet}% (resets {weekly_resets_str}) · "
    f"API pool: ${api_spend:.2f}/${api_limit:.0f} ({api_tier}, resets {api_resets}) · Extra usage: {extra_str}"
)
line3 = f"{throttle_phrase} · refreshed {today}"

new_directive = (
    "Cost tally format: end every response with a bold header and a three-line tally:\n\n"
    "**Cost tally**\n"
    f"{line1}\n"
    f"{line2}\n"
    f"{line3}"
)

# All known older tally directive patterns (L7 backward compat)
patterns = [
    re.compile(r'Cost tally format: end every response with "Tokens: ~Xk in / ~Y out · Session: ~\$Z\.ZZ"\.'),
    re.compile(r'Cost tally format: end every response with TWO lines:\s*\n  Tokens: ~Xk in / ~Y out · Session: ~\$Z\.ZZ\s*\n  Plan: [^\n]+'),
    re.compile(r'Cost tally format: end every response with FOUR lines:\s*\n  Tokens: ~Xk in / ~Y out · Session: ~\$Z\.ZZ\s*\n  Plan: [^\n]+\n  Throttle: [^\n]+\n  ⚠ Stale[^\n]+'),
    re.compile(r'Cost tally format: end every response with a bold header and a single-line tally:\s*\n\s*\n\*\*Cost tally\*\*\s*\n~Xk in / ~Y out[^\n]+'),
    re.compile(r'Cost tally format: end every response with a bold header and a two-line tally:\s*\n\s*\n\*\*Cost tally\*\*\s*\n~Xk in / ~Y out[^\n]*\nThrottle: [^\n]*'),
    re.compile(r'Cost tally format: end every response with a bold header and a three-line tally:\s*\n\s*\n\*\*Cost tally\*\*\s*\n~Xk in / ~Y out[^\n]*\nSession: [^\n]*\nThrottle: [^\n]*'),
]

# --- L7 update ---
updated = 0
if l7_dir != "-" and os.path.isdir(l7_dir):
    for fname in sorted(os.listdir(l7_dir)):
        if not fname.endswith(".md"): continue
        path = os.path.join(l7_dir, fname)
        with open(path) as f: content = f.read()

        matched = False
        for pat in patterns:
            if pat.search(content):
                content_new = pat.sub(new_directive, content)
                with open(path, "w") as f: f.write(content_new)
                updated += 1
                print(f"  ✓ L7 updated {fname}")
                matched = True
                break
        if not matched:
            print(f"  ⚠ {fname}: no recognizable directive, skipping")

    print(f"\n✓ Emitted v3.5.2 to {updated} L7 file(s)")
elif l7_dir != "-":
    print(f"  ⚠ L7 dir not found: {l7_dir}", file=sys.stderr)

# --- L2 update (Cowork global instructions) ---
if l2_path:
    if not os.path.isfile(l2_path):
        print(f"  ✗ L2 file not found: {l2_path}", file=sys.stderr)
    else:
        with open(l2_path) as f:
            content = f.read()

        # Region 1: cost tally block — "**Cost tally**\n<line1>\n<line2>\n<line3>"
        tally_block_new = f"**Cost tally**\n{line1}\n{line2}\n{line3}"
        tally_pat = re.compile(r'\*\*Cost tally\*\*\n~Xk in[^\n]*\nSession:[^\n]*\nThrottle:[^\n]*')
        if tally_pat.search(content):
            content = tally_pat.sub(tally_block_new, content)
            print(f"  ✓ L2 cost tally block updated")
        else:
            print(f"  ⚠ L2: cost tally block pattern not found — check formatting")

        # Region 2: plan + cost context section
        month_name = datetime.now().strftime("%B")
        extra_note = "subscription overages get blocked rather than charging the API pool" if not extra_enabled else "overages charge the API pool"
        plan_display = (plan[0].upper() + plan[1:]).replace("-", " ")
        new_context = (
            f"## Plan + cost context (corrected — two-pool model)\n"
            f"- Currently on {plan_display} (${fee}/mo, renews {renewal})\n"
            f"- ccusage retail-equivalent for {month_name} MTD: ~${ccusage_mtd:.2f} ({ratio}× plan fee = {verdict}, {throttle_mtd} throttle hits)\n"
            f"- **Pay-as-you-go pool (single):** ${api_spend:.2f} of ${api_limit:.0f} customer cap ({api_tier} ceiling: ${api_ceiling:.0f}). Covers all API-rate billing — both API direct calls ([YOUR_PROJECT] when live) and subscription extra usage above plan limits. Resets {api_resets}.\n"
            f"- Extra usage toggle: {extra_str} ({extra_note})\n"
            f"- Console credit balance: ${credit_balance:.2f} (auto-reload ${auto_reload_threshold} → ${auto_reload_amount})\n"
        )
        context_pat = re.compile(
            r'## Plan \+ cost context.*?(?=\n## )',
            re.DOTALL
        )
        if context_pat.search(content):
            content = context_pat.sub(new_context, content)
            print(f"  ✓ L2 plan + cost context updated")
        else:
            print(f"  ⚠ L2: plan + cost context section not found")

        with open(l2_path, "w") as f:
            f.write(content)
        print(f"  ✓ L2 written: {l2_path}")

# --- L3-global update (~/.claude/CLAUDE.md) ---
if l3_global_path:
    if not os.path.isfile(l3_global_path):
        print(f"  ✗ L3-global file not found: {l3_global_path}", file=sys.stderr)
    else:
        with open(l3_global_path) as f:
            content = f.read()

        tally_block_new = f"**Cost tally**\n{line1}\n{line2}\n{line3}"
        tally_pat = re.compile(r'\*\*Cost tally\*\*\n~Xk in[^\n]*\nSession:[^\n]*\nThrottle:[^\n]*')
        if tally_pat.search(content):
            content = tally_pat.sub(tally_block_new, content)
            print(f"  ✓ L3-global cost tally block updated")
        else:
            print(f"  ⚠ L3-global: cost tally block pattern not found — check formatting")

        with open(l3_global_path, "w") as f:
            f.write(content)
        print(f"  ✓ L3-global written: {l3_global_path}")

print(f"\n  **Cost tally**")
print(f"  {line1}")
print(f"  {line2}")
print(f"  {line3}")

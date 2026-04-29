#!/bin/zsh
# =============================================================================
# update-claude-cost — v3.4.1 (subscription-aware + throttle event tracking)
#
# Tracks two signals + throttle events:
#   1. Subscription value (ccusage retail-equivalent vs plan fee)
#   2. API pool burn (when production apps call Anthropic API directly)
#   3. Throttle events (when, where, reset time, downtime minutes)
#
# Usage:
#   update-claude-cost                              Show current state
#   update-claude-cost --code                       Refresh ccusage (auto, daily)
#   update-claude-cost --plan max-20x --fee 200     Set/update subscription
#   update-claude-cost --balance 14.57              Update Console credit balance
#   update-claude-cost --burn 285                   Set recent monthly API burn
#   update-claude-cost --throttle [args]            Record a throttle event:
#       --surface chat|cowork|code                  Which surface hit the limit
#       --reset-at "19:00"                          When the limit resets (HH:MM today)
#       --reset-at "2026-04-29T09:00"               Or full ISO timestamp
#       --context "<short note>"                    Optional context
#   update-claude-cost --tier-test max-5x           Begin testing a smaller tier
#   update-claude-cost --monthly-review             Generate the monthly decision-aid report
#   update-claude-cost --reset                      New month (preserves history)
# =============================================================================

set -e
COST_FILE=~/.claude/cumulative-cost.json
ARCHIVE_DIR=~/.claude/cost-archive
mkdir -p ~/.claude "$ARCHIVE_DIR"

# Initialize if missing
if [[ ! -f "$COST_FILE" ]]; then
  CURRENT_MONTH=$(date +%Y-%m)
  cat > "$COST_FILE" << JSONEOF
{
  "month": "$CURRENT_MONTH",
  "schema_version": "3.4.1",
  "subscription": {
    "plan": "max-20x",
    "monthly_fee_usd": 200,
    "renewal_date": null,
    "throttle_events": [],
    "throttle_hits_mtd": 0,
    "total_downtime_mtd_minutes": 0
  },
  "api_pool": {
    "credit_balance": 0.00,
    "balance_updated": null,
    "auto_reload_threshold": 5,
    "auto_reload_amount": 15,
    "recent_monthly_burn": 0.00,
    "active": false
  },
  "value_signal": {
    "ccusage_mtd": 0.00,
    "ratio_to_plan_fee": 0.00,
    "verdict": "no data",
    "downgrade_candidate": false
  },
  "tier_test": {
    "last_test": null,
    "next_check": null,
    "candidate_plan": null,
    "candidate_fee": null,
    "test_status": "none"
  }
}
JSONEOF
  echo "Initialized $COST_FILE for month $CURRENT_MONTH"
fi

# Auto-detect new month (skip on --reset and --monthly-review)
CURRENT_MONTH=$(date +%Y-%m)
STORED_MONTH=$(jq -r .month "$COST_FILE")
if [[ "$STORED_MONTH" != "$CURRENT_MONTH" && "$1" != "--reset" && "$1" != "--monthly-review" ]]; then
  echo "⚠ New month: stored=$STORED_MONTH, current=$CURRENT_MONTH"
  echo "  Run: update-claude-cost --monthly-review (to see last month's decision aid)"
  echo "  Then: update-claude-cost --reset (to start the new month)"
  exit 1
fi

# Recompute aggregates
recompute() {
  CCUSAGE=$(jq .value_signal.ccusage_mtd "$COST_FILE")
  FEE=$(jq .subscription.monthly_fee_usd "$COST_FILE")
  THROTTLE=$(jq .subscription.throttle_hits_mtd "$COST_FILE")
  DOWNTIME=$(jq .subscription.total_downtime_mtd_minutes "$COST_FILE")

  if (( $(python3 -c "print(1 if $FEE == 0 else 0)") )); then
    RATIO="0.00"
  else
    RATIO=$(python3 -c "print(round($CCUSAGE / $FEE, 2))")
  fi

  # Verdict: combines ratio + throttle + downtime
  if (( $(python3 -c "print(1 if $CCUSAGE == 0 else 0)") )); then
    VERDICT="no data — run --code"
    DOWNGRADE="false"
  elif (( $(python3 -c "print(1 if $RATIO < 0.5 else 0)") )); then
    VERDICT="⚠ under-utilizing — strong downgrade signal"
    DOWNGRADE="true"
  elif (( $(python3 -c "print(1 if $RATIO < 1.0 else 0)") )); then
    VERDICT="⚠ below break-even"
    DOWNGRADE="true"
  elif (( $(python3 -c "print(1 if $RATIO < 3.0 else 0)") )); then
    VERDICT="✓ plan justified ($RATIO×, no concerns)"
    DOWNGRADE="false"
  elif (( $(python3 -c "print(1 if $THROTTLE >= 3 or $DOWNTIME >= 500 else 0)") )); then
    VERDICT="✓ saturated — plan correctly sized ($RATIO×, $THROTTLE hits, ${DOWNTIME}min downtime)"
    DOWNGRADE="false"
  elif (( $(python3 -c "print(1 if $THROTTLE > 0 else 0)") )); then
    VERDICT="✓ working well ($RATIO×, $THROTTLE minor throttle hits) — plan size right"
    DOWNGRADE="false"
  else
    VERDICT="✓ extracting $RATIO× value, no throttling — DOWNGRADE CANDIDATE"
    DOWNGRADE="true"
  fi

  jq --argjson r "$RATIO" --arg v "$VERDICT" --argjson d "$([ "$DOWNGRADE" = "true" ] && echo true || echo false)" \
     '.value_signal.ratio_to_plan_fee = $r
      | .value_signal.verdict = $v
      | .value_signal.downgrade_candidate = $d' \
     "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"

  BURN=$(jq .api_pool.recent_monthly_burn "$COST_FILE")
  if (( $(python3 -c "print(1 if $BURN > 5 else 0)") )); then
    ACTIVE=true
  else
    ACTIVE=false
  fi
  jq --argjson a "$ACTIVE" '.api_pool.active = $a' "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
}

# Convert HH:MM (today) or full ISO to ISO timestamp
to_iso_timestamp() {
  local input="$1"
  if [[ "$input" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    # HH:MM today
    echo "$(date +%Y-%m-%d)T${input}:00Z"
  else
    # Assume already ISO
    echo "$input"
  fi
}

# Throttle event handling
record_throttle() {
  local SURFACE="unknown"
  local RESET_AT=""
  local CONTEXT=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --surface) SURFACE="$2"; shift 2 ;;
      --reset-at) RESET_AT=$(to_iso_timestamp "$2"); shift 2 ;;
      --context) CONTEXT="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local NOW
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Compute downtime if reset_at provided
  local DOWNTIME=0
  if [[ -n "$RESET_AT" ]]; then
    DOWNTIME=$(python3 -c "
from datetime import datetime
try:
    now = datetime.fromisoformat('$NOW'.replace('Z','+00:00'))
    rst = datetime.fromisoformat('$RESET_AT'.replace('Z','+00:00'))
    print(max(0, int((rst - now).total_seconds() / 60)))
except Exception as e:
    print(0)
")
  fi

  jq --arg ts "$NOW" --arg surf "$SURFACE" --arg rst "$RESET_AT" --argjson dt "$DOWNTIME" --arg ctx "$CONTEXT" \
     '.subscription.throttle_events += [{
        "timestamp": $ts,
        "surface": $surf,
        "reset_at": ($rst | if . == "" then null else . end),
        "downtime_minutes": $dt,
        "context": ($ctx | if . == "" then null else . end)
      }]
      | .subscription.throttle_hits_mtd += 1
      | .subscription.total_downtime_mtd_minutes += $dt' \
     "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"

  echo "✓ Throttle event recorded: $SURFACE${RESET_AT:+ (resets at $RESET_AT, ${DOWNTIME}min downtime)}"
}

# Monthly review report
monthly_review() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Monthly Subscription Review — $(jq -r .month $COST_FILE)"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  jq -r '
    "Plan:           \(.subscription.plan) at $\(.subscription.monthly_fee_usd)/mo",
    "Value extracted: $\(.value_signal.ccusage_mtd) (\(.value_signal.ratio_to_plan_fee)× plan fee)",
    "Throttle hits:  \(.subscription.throttle_hits_mtd)",
    "Total downtime: \(.subscription.total_downtime_mtd_minutes) minutes",
    ""
  ' "$COST_FILE"

  echo "Verdict: $(jq -r .value_signal.verdict $COST_FILE)"
  echo ""

  RATIO=$(jq .value_signal.ratio_to_plan_fee $COST_FILE)
  THROTTLE=$(jq .subscription.throttle_hits_mtd $COST_FILE)
  DOWNTIME=$(jq .subscription.total_downtime_mtd_minutes $COST_FILE)
  PLAN=$(jq -r .subscription.plan $COST_FILE)

  echo "DECISION AID:"
  if (( $(python3 -c "print(1 if $RATIO >= 3 and $THROTTLE >= 3 else 0)") )) || (( $(python3 -c "print(1 if $DOWNTIME >= 500 else 0)") )); then
    echo "  → PLAN CORRECTLY SIZED. Stay on $PLAN."
    echo "    High value extraction + throttle hits = saturated subscription."
  elif (( $(python3 -c "print(1 if $RATIO >= 1 and $THROTTLE == 0 else 0)") )); then
    echo "  → DOWNGRADE CANDIDATE."
    echo "    Good value but no throttling means you're not using the plan's headroom."
    echo "    Consider testing the next-smaller tier next cycle."
    echo "    To start a test: update-claude-cost --tier-test <smaller-plan>"
  elif (( $(python3 -c "print(1 if $RATIO < 1 else 0)") )); then
    echo "  → DOWNGRADE STRONGLY RECOMMENDED."
    echo "    You're not breaking even on the subscription."
  else
    echo "  → MONITOR ANOTHER CYCLE."
    echo "    Mixed signals — wait one more month before changing the plan."
  fi
  echo ""
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --code)
      if ! command -v ccusage &>/dev/null; then
        echo "ccusage not installed. Run: npm install -g ccusage"
        exit 1
      fi
      MTD=$(ccusage --since "$(date +%Y%m01)" --until "$(date +%Y%m%d)" --json 2>/dev/null \
            | jq -r '.totals.totalCost // 0' 2>/dev/null \
            | python3 -c "import sys; v=sys.stdin.read().strip(); print(round(float(v) if v and v != 'null' else 0, 2))" 2>/dev/null \
            || echo "0.00")
      [[ -z "$MTD" || "$MTD" == "null" ]] && MTD="0.00"
      jq --argjson mtd "$MTD" '.value_signal.ccusage_mtd = $mtd' "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      echo "✓ ccusage MTD refreshed: \$$MTD"
      shift
      ;;
    --plan)
      jq --arg p "$2" '.subscription.plan = $p' "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      shift 2 ;;
    --fee)
      jq --argjson v "$2" '.subscription.monthly_fee_usd = $v' "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      shift 2 ;;
    --balance)
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      jq --argjson v "$2" --arg n "$NOW" \
         '.api_pool.credit_balance = $v | .api_pool.balance_updated = $n' \
         "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      echo "✓ API pool balance: \$$2"
      shift 2 ;;
    --burn)
      jq --argjson v "$2" '.api_pool.recent_monthly_burn = $v' "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      shift 2 ;;
    --throttle)
      shift
      record_throttle "$@"
      # consume the rest of args that belong to throttle
      while [[ $# -gt 0 && "$1" =~ ^-- ]]; do shift; done
      ;;
    --tier-test)
      NEXT_CHECK=$(date -v+1m +%Y-%m-%d 2>/dev/null || date -d '+1 month' +%Y-%m-%d)
      jq --arg p "$2" --arg d "$NEXT_CHECK" \
         '.tier_test.candidate_plan = $p
          | .tier_test.next_check = $d
          | .tier_test.test_status = "in-progress"
          | .tier_test.last_test = (now | todate)' \
         "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      echo "✓ Tier test started: $2 (review on $NEXT_CHECK)"
      shift 2 ;;
    --monthly-review)
      monthly_review
      exit 0
      ;;
    --reset)
      cp "$COST_FILE" "$ARCHIVE_DIR/cumulative-cost-$(date +%Y-%m-%d).json"
      jq --arg m "$CURRENT_MONTH" \
         '.month = $m
          | .value_signal.ccusage_mtd = 0.00
          | .subscription.throttle_hits_mtd = 0
          | .subscription.total_downtime_mtd_minutes = 0
          | .subscription.throttle_events = []' \
         "$COST_FILE" > "$COST_FILE.tmp" && mv "$COST_FILE.tmp" "$COST_FILE"
      echo "✓ Reset for $CURRENT_MONTH (archived to $ARCHIVE_DIR)"
      shift ;;
    *)
      shift ;;
  esac
done

recompute

echo ""
echo "════ Claude cost — month $(jq -r .month $COST_FILE) ════"
echo ""
echo "▸ Subscription"
jq -r '"  Plan: \(.subscription.plan) at $\(.subscription.monthly_fee_usd)/mo",
       "  Throttle hits this month: \(.subscription.throttle_hits_mtd) (\(.subscription.total_downtime_mtd_minutes) min downtime)"' "$COST_FILE"

echo ""
echo "▸ Subscription value"
jq -r '"  ccusage MTD:  $\(.value_signal.ccusage_mtd) (retail-equivalent value)",
       "  Value ratio:  \(.value_signal.ratio_to_plan_fee)× plan fee",
       "  Verdict:      \(.value_signal.verdict)"' "$COST_FILE"

echo ""
echo "▸ API pool (Console credits — for direct API usage)"
jq -r '"  Balance: $\(.api_pool.credit_balance) (updated: \(.api_pool.balance_updated // "never"))",
       "  Recent burn: $\(.api_pool.recent_monthly_burn)/mo · Active: \(.api_pool.active)"' "$COST_FILE"

THROTTLE_COUNT=$(jq '.subscription.throttle_events | length' "$COST_FILE")
if [[ "$THROTTLE_COUNT" -gt 0 ]]; then
  echo ""
  echo "▸ Recent throttle events (last 5)"
  jq -r '.subscription.throttle_events[-5:] | reverse | .[] | "  \(.timestamp[0:16]) · \(.surface) · \(.downtime_minutes)min · \(.context // "no context")"' "$COST_FILE"
fi

TIER_STATUS=$(jq -r .tier_test.test_status "$COST_FILE")
if [[ "$TIER_STATUS" != "none" ]]; then
  echo ""
  echo "▸ Tier test in progress"
  jq -r '"  Candidate: \(.tier_test.candidate_plan) · Status: \(.tier_test.test_status) · Next check: \(.tier_test.next_check)"' "$COST_FILE"
fi

echo ""

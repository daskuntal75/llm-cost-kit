---
name: Subscription-limits refresh prompt
purpose: Surface a clickable ⚖️ Decision when subscription-limits data (session %, weekly %, throttle, daily routines) is more than 7 days stale, so the cost tally isn't lying. Anthropic doesn't expose these via API; refresh requires the user copying from claude.ai/settings/usage.
applies_to: Code (interactive + autonomous), Chat, Cowork. Same staleness rule across all surfaces.
locked: 2026-05-15
---

# The rule in one sentence

**At the first cost-tally moment of any session (Code/Chat/Cowork), check `subscription.session_limit.last_updated` in `cumulative-cost.json`. If > 7 days old, emit a ⚖️ Decision block with a one-click refresh path.**

# Why this matters

- The Anthropic API does NOT expose individual-user session/weekly subscription limits. The only source of truth is the web UI at https://claude.ai/settings/usage.
- The hourly LaunchAgent `com.kuntal.cumulative-cost.plist` refreshes `ccusage_mtd` and `throttle_hits_mtd`, but does NOT refresh `session_limit.percent_used` or `weekly_*.percent_used`. Those go stale silently.
- Without a refresh prompt, the cost tally shows numbers that are weeks old → user trusts them → over-allocates → hits surprise throttles.

# Triggering the prompt — at first cost-tally moment

In any session that emits a cost tally:

1. Read `~/.claude/cumulative-cost.json`'s `subscription.session_limit.last_updated` ISO timestamp.
2. Compute `age_days = (now - last_updated) / 86400`.
3. Read snooze file `~/.local/state/limits-refresh-snooze-until.txt`. If present, parse ISO timestamp; if `now < snooze_until`, skip the prompt.
4. If `age_days > 7` AND not snoozed → emit the Decision block.

# The Decision block

Use the standard ⚖️ Decision clickable structure (per CLAUDE.md §Decision-request format).

```
⚖️ **Decision:** Refresh subscription limits? Current data is <N> days stale.
**If we don't decide →** the cost tally keeps showing N-day-old Session %, Weekly %, and Throttle counts — you may misjudge headroom

Options:
⭐ Refresh now — open claude.ai/settings/usage, paste values, run update-claude-cost
   Skip — *why not*: cost tally stays stale; OK for short sessions but not before bulk autonomous runs
   Don't ask this week — *why not*: only choose if you've checked recently outside of this prompt
```

In Claude Code: use `AskUserQuestion` with these three options. Recommended option prefixed `(Recommended)`. The no-action consequence sits in the question body.

# The refresh workflow (Code)

When user picks ⭐ Refresh now:

1. `open https://claude.ai/settings/usage` (macOS opens the URL in default browser).
2. Tell user: *"I'll wait. Copy the limits section (Current session %, Weekly all/Sonnet/Design %, Daily routines used/total, Extra usage on/off) and paste back."*
3. Wait for paste. Parse the typical format:
   - `Current session ... N% used`
   - `All models ... N% used`
   - `Sonnet only ... N% used` (or "haven't used Sonnet yet" → 0)
   - `Claude Design ... N% used` (or "haven't used Claude Design yet" → 0)
   - `Daily included routine runs ... N / M` (or "haven't run any routines" → 0/N)
   - `Extra usage ... <amount> spent` → `off` if "$0.00 spent / 0% used" and the toggle is off
4. Run the refresh command:
   ```bash
   update-claude-cost \
     --set-session <N> \
     --set-weekly-all <N> \
     --set-weekly-sonnet <N> \
     --set-weekly-design <N> \
     --set-daily-routines <N> <M> \
     --set-extra-usage off|on
   ```
5. Confirm: *"Refreshed. Session N%, Weekly N/N/N%, Daily N/M, Extra off. Next prompt in 7 days unless I see a throttle event."*

# The refresh workflow (Chat / Cowork)

Chat/Cowork can't shell-exec. The Decision block instead surfaces the instructions:

```
⚖️ **Decision:** Refresh subscription limits? Current data is <N> days stale.
**If we don't decide →** the static-snapshot cost tally in this thread shows stale values

Options:
⭐ I'll refresh on my Mac now — open claude.ai/settings/usage, then run the command below
   Skip — *why not*: snapshot stays stale
   Don't ask this week — *why not*: only if already refreshed recently

Refresh command (paste these values on Mac after copying from claude.ai/settings/usage):
update-claude-cost --set-session <N> --set-weekly-all <N> --set-weekly-sonnet <N> --set-weekly-design <N> --set-daily-routines <N> <M> --set-extra-usage off|on
```

Then in this same response, re-emit the cost tally with fresh values once the user reports back.

# Snooze logic

If user picks "Don't ask this week":

```bash
SNOOZE_FILE="$HOME/.local/state/limits-refresh-snooze-until.txt"
mkdir -p "$(dirname "$SNOOZE_FILE")"
date -v+7d -u +%Y-%m-%dT%H:%M:%SZ > "$SNOOZE_FILE"
```

Future sessions read this file and skip the prompt until the snooze time passes.

# Where the staleness check fires

| Surface | When |
|---|---|
| **Code** (interactive) | First cost tally of the session (i.e., end of first response). Also: before any `/loop` or `/schedule` cron fires (pre-flight check). |
| **Chat** | First response in a thread that ends with a cost tally. If thread continues, skip subsequent checks (one-per-thread). |
| **Cowork** | Same as Chat (one-per-thread). |

# What the cost tally looks like with staleness markers

When fresh (≤ 7 days):
```
Plan max-20x $200/mo (renews 2026-05-21 → max-5x $100/mo, Extra OFF) · Limits Sess 7%, Wk 1%/0%/0%, Throttle 0 (as of today, resets Sun 9:59 AM)
```

When stale (> 7 days):
```
Plan max-20x $200/mo · ⚠ Limits STALE (as of 2026-05-03): Sess 24%, Wk 0%/0% — refresh via claude.ai/settings/usage
```

# Field reference (so users can map UI → flags)

| Web UI label (claude.ai/settings/usage) | `update-claude-cost` flag |
|---|---|
| Current session N% used | `--set-session N` |
| Resets in 2h 53min | `--set-session-resets-in "2h 53min"` |
| All models N% used | `--set-weekly-all N` |
| Sonnet only N% used | `--set-weekly-sonnet N` |
| Claude Design N% used | `--set-weekly-design N` |
| Resets Sun 9:59 AM | `--set-weekly-resets-at "Sun 9:59 AM"` |
| Daily included routine runs N / M | `--set-daily-routines N M` |
| Extra usage … (toggle on/off) | `--set-extra-usage on|off` |

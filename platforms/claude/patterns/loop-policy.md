# Autonomous loop policy (locked 2026-06-10, founder-dictated)

Durable rules for every long-running `/loop` / autonomous worklist execution, on every Claude deployment (Code, cloud routines, future Macs). Supersedes the 2026-05 "loop never self-merges" rule and all per-session merge authorizations. Repo-local copies live in each project's git-tracked `CLAUDE.md`; this file is the canonical spec.

## Scope

The work queue is the ENTIRE backlog of the active project(s), top to bottom (P0 → P3, grouped by capability epic), not a per-session shortlist. A prioritized head list in a handoff sets ORDER, never the boundary. When the head list is done, continue down the backlog.

## The ONLY three halt conditions

The loop halts the whole session ONLY when one of these fires:

1. **Out-of-pocket cost > $20 for the loop.** Out-of-pocket = money beyond the flat subscription: Console API-pool spend delta (auto-check via `update-claude-cost --pull-api-spend`) plus claude.ai Extra-usage-credits delta when a refreshed number is available. Subscription-included tokens do NOT count. Snapshot both at loop start. If Extra spend cannot be measured mid-loop, treat any session-limit throttle event as the trigger to pause and check.
2. **Backlog exhausted.** Nothing remaining anywhere in the backlog can progress without founder intervention (every remaining item is parked on a founder decision, credential, or external dependency).
3. **Critical production issue** that requires founder intervention (user-facing outage or data-integrity risk in prod that the loop cannot safely fix alone).

Everything that previously halted a session (would-be force-push, security-tier conflict, unexplained CI failure, new-locked-decision moment, > $1 agent run, etc.) now PARKS that item with a ⚖️ Decision and the loop continues with the next eligible item. The loop never performs those actions autonomously; it just doesn't stop the session over them.

## Per-activity test duty (every item, no exceptions)

For every activity, FIRST determine which of these test categories the change needs, and create the missing ones in the same PR: **unit · regression · smoke · security · performance · scalability**. Most changes need a subset; the determination itself is mandatory and stated in the PR body (a "Tests considered" line listing each category as added / existing / not-applicable-because).

## Merge authority (full, conditional)

- **→ develop:** auto-merge a PR when its CI is fully green (job-level verification, never run-level only).
- **→ main:** auto-merge a release train when the develop merge produced a fully green pipeline INCLUDING all applicable test categories above, at job level. If all green and passed, the loop has FULL authority to merge to main without founder intervention. Merge-commit for trains (anti-phantom-drift).
- **→ prod:** NEVER autonomous. Prod deploys remain release-tag-gated, and the tag is created only AFTER (a) a successful merge to main AND (b) the founder confirms manual testing. The loop parks a ⚖️ tag gate with a manual-test checklist and continues with other work.

## Operating rules carried over (unchanged)

Branch from origin/develop · tests in the same PR (Definition of Done) · max 1 concurrent working-tree-writing sub-agent on Drive-synced repos · end-of-iteration ToDo/blocker briefing · memory-first persistence of decisions · evidence-first debugging after 1 unexplained CI failure (park the item if evidence requires founder input).

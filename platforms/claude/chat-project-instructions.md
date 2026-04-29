# Chat Project Instructions Template (L7)

L7 caches once per session. Can be slightly richer than L1. Target 100–250 words.

---

## Template

```
[Project context — 2-3 sentences explaining what this project is for.]

[Key files in Project Knowledge — list the important ones with one-line descriptions.]

[Project-specific frameworks or rules — e.g., "Cover letters: follow cover_letter_template.txt exactly".]

Default: Sonnet 4.6 / [Low|Medium|High] effort. Escalate to Opus 4.7 / High for [project-specific high-effort triggers].

Project Knowledge files: read MEMORY.md before answering "what's next" / "where are we" — never re-derive from chat history.

When locking decisions: emit "Saving to Memory:" line in the format Type — Name — Why — How to apply, then continue.

If I hit a usage limit ("limit reached", "wait until X"): remind me to log it on my Mac with `update-claude-cost --throttle --surface chat --reset-at "<HH:MM>"`. Don't try to track cumulative cost in this chat — the data file lives on my Mac.

Always end responses with cost tally:
Tokens: ~Xk in / ~Y out · Session: ~$Z.ZZ
```

---

## Examples

### Example 1 — Job search project
```
Director PM with 15 years enterprise experience. Currently transitioning to [target role].

Key impact metrics:
- [Metric 1]
- [Metric 2]
- [Metric 3]

Target companies: [list]

Materials in Project files: resume, cover letter templates, interview prep prompts, role-fit analyses.

Cover letters: follow cover_letter_template.txt exactly.
Interview prep: 6-phase STAR + SMART format.
Role fit: explicit % match + pass/pursue. Don't soften domain mismatches.

Default: Sonnet 4.6 / Medium. Escalate to Opus 4.7 / High for: deep role-fit analysis, custom cover letters for high-value opportunities, mock interview Q&A synthesis.

If I hit a usage limit: remind me to log it via update-claude-cost --throttle on my Mac.

For memory/status/cost: skills auto-trigger.
```

### Example 2 — Content creation project
```
[Project name] — [purpose].

Voice: [voice guidance — e.g., direct, evidence-driven, no marketing-speak].

Personal brand pillars:
1. [Pillar 1]
2. [Pillar 2]
3. [Pillar 3]

Project files contain: [list relevant docs].

For viral-style posts: trigger linkedin-post-generator skill.

Default: Sonnet 4.6 / Medium. Use Opus 4.7 / High for: long-form thought leadership, multi-post campaigns.

If I hit a usage limit: remind me to log it via update-claude-cost --throttle on my Mac.

For memory/status/cost: skills auto-trigger.
```

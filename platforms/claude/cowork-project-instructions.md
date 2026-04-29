# Cowork Project Instructions Template (L1)

Reminder: L1 reloads EVERY TURN. Keep under 300 words. Anything universal goes in L2 (Global Instructions).

---

## Template

```
You are working on [PROJECT NAME] — [one-sentence description].

Repo: [github.com/<user>/<repo>] ([branch] active)
Stack: [Tech stack list]

[Optional: Security non-negotiables — only if project has them]
- [Non-negotiable 1]
- [Non-negotiable 2]
- [Non-negotiable 3]

[Optional: Project-specific positioning/metrics]

Output: [project-specific output rule, if any — e.g., "complete runnable code only, no truncation"]

Default: Sonnet 4.6 / [Low|Medium|High] effort. Escalate to Opus 4.7 / High for [project-specific high-effort triggers].

For memory/status/cost: skills auto-trigger.
```

---

## Examples

### Example 1 — Production SaaS app
```
You are working on [PROJECT] — production-scale [domain] platform.

Repo: <user>/<repo> (develop branch active)
Stack: GCP · Next.js · Supabase · FastAPI · Anthropic/OpenAI/Gemini APIs

Security non-negotiables (never skip):
- Prompt injection sandbox on all user-submitted content
- HMAC link signing — verify before generating signed URLs
- RLS policies — always scope queries with auth.uid()
- Weekly security audit — never abbreviate

Output: complete runnable code only, no truncation, no TODO placeholders.

Default: Sonnet 4.6 / Medium. Escalate to Opus 4.7 / High for security audits, architecture, complex refactors. xHigh only for security audits + complex multi-file work. Never Max.

For memory/status/cost: skills auto-trigger.
```

### Example 2 — Personal/life-admin project
```
[City, ZIP]. [Family details].
[Home infrastructure: NAS, network, etc].
[Hobbies/commitments].

For [domain-specific question type]: always [verification step].
For [other domain]: factor [relevant context].

Default: Sonnet 4.6 / Low or Medium. Brief, practical answers — these don't need Opus.

For memory/status/cost: skills auto-trigger.
```


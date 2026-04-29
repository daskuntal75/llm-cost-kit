# Output Rules — L4 User Preferences

These are universal output rules that apply across all workspaces (Chat, Cowork, Code via web). Paste into Claude Settings → Profile → Preferences.

For OpenAI: paste into ChatGPT Settings → Personalization → Custom Instructions.
For Gemini: paste into Gem builder system instructions.

---

## Rules

```
Respond concisely. Lead with the answer, not the reasoning.
No openers (Great!, Sure!, Certainly!).
No closers (Let me know if you need anything!).
Tables over prose for comparisons.
One recommendation, not a menu of options.
If I ask a yes/no question, answer it first.
Complete, runnable code only — no truncation, no TODO placeholders.
```

---

## Why this layer

L4 (account-wide preferences) is the most cost-efficient layer in the entire hierarchy. It loads once per session at zero per-turn cost and applies universally. Use it as the foundation for output discipline; everything else (L1, L2, L7) can reference it.


# LLM Cost Kit

> 40-70% cost reduction for Claude, ChatGPT, and Gemini — without quality loss.

A complete, layered architecture for managing instructions across all surfaces of an LLM workflow.

## Download

Pick the kit for your platform from [Releases](https://github.com/daskuntal75/llm-cost-kit/releases/latest):

| Kit | For |
|---|---|
| `claude-cost-kit.zip` | Claude.ai, Claude Code, Cowork users |
| `openai-cost-kit.zip` | ChatGPT, Custom GPTs, OpenAI API |
| `gemini-cost-kit.zip` | Gemini, Gem builder, AI Studio |
| `llm-cost-kit.zip` | All three platforms in one bundle |

## The 7-layer hierarchy

The most important concept in this kit. Where you put your instructions matters as much as what they say.

![Hierarchy diagram](diagrams/hierarchy-diagram.png)

## Decision tree — where should this rule go?

For any new instruction, walk this tree to find the right layer.

![Decision tree](diagrams/decision-tree-diagram.png)

## Quick start

### Before you start — have these ready

| Need | Where to get it | Why |
|---|---|---|
| Apple ID password | — | Mac initial setup, App Store, iCloud |
| GitHub credentials | github.com | `bootstrap-macos.sh` runs `gh auth login` (opens browser) |
| Anthropic account | claude.ai | First `claude` CLI run does OAuth |
| Anthropic Admin API key *(optional)* | console.anthropic.com → Settings → Admin Keys | Enables `update-claude-cost --pull-api-spend` |
| Skills-source repo URL *(optional)* | your private GitHub | The setup will offer to bootstrap `~/dev/skills-source/` |
| Your plan details | claude.ai/settings/billing | Need plan name, monthly fee, renewal date for step 5 |

### Fresh Mac (Mac Mini, new laptop) — 3 scripts, ~30 min

```bash
git clone https://github.com/daskuntal75/llm-cost-kit ~/dev/llm-cost-kit
cd ~/dev/llm-cost-kit

# 1. Pre-flight: brew, node, jq, fswatch, gh, Claude Desktop, gh auth login
bash bootstrap-macos.sh

# 2. One-time Anthropic OAuth (browser opens)
claude

# 3. Main setup: Claude Code CLI, ccusage, MCP configs, aliases, skills, cost LaunchAgent
bash setup.sh
source ~/.zshrc

# 4. Initialize your cost state
update-claude-cost --plan YOUR_PLAN --fee YOUR_MONTHLY_FEE --renews YYYY-MM-DD

# 5. Verify: green/red dashboard
bash verify.sh
```

### Already have a working Mac

Skip step 1. Just `bash setup.sh` then `bash verify.sh`.

### After the scripts — manual web-UI steps (~20 min, cannot be scripted)

| Layer | Paste from (in repo) | Paste to |
|---|---|---|
| **L4** universal | `core/OUTPUT_RULES.md` | claude.ai → Settings → Profile → Preferences |
| **L2** Cowork global | `platforms/claude/cowork-global-instructions.md` | claude.ai → Cowork → Settings → Global Instructions |
| **L1** per Cowork project | `platforms/claude/cowork-project-instructions.md` (tailored) | each Cowork project's instructions |
| **L7** per Chat project | `platforms/claude/chat-project-instructions.md` (tailored) | each Chat project's instructions |
| **L6** skills | `~/dev/skills-source/.build/*.skill` | claude.ai → Cowork → Customize → Skills → Install from file |
| **MCP Connectors** | n/a | https://claude.ai/settings/connectors — re-auth Gmail, Drive, Calendar, Granola, Gamma, Stripe, Supabase |

Then re-run `bash verify.sh` — the L3-global check confirms instruction files landed.

### Heads-up

1. **Don't reuse an old `~/.claude` from a Time Machine restore.** Let `bootstrap-macos.sh` + first `claude` run create fresh state. Old MCP tokens will fail silently and waste a debugging hour.
2. **Run `verify.sh` twice — once after the scripts, once after the manual paste work.** The first run confirms the automated half; the second catches anything you missed in the UI.

Hourly pipeline auto-refreshes L2 + L3-global + L7 cost tally. See [`platforms/claude/scripts/cumulative-cost-launchagent.sh`](platforms/claude/scripts/cumulative-cost-launchagent.sh).

## What's new in v3.6

- **`bootstrap-macos.sh`** — pre-flight installer for a bare Mac. Handles Xcode CLT, Homebrew, node, jq, fswatch, git, gh, Claude Desktop cask. Idempotent.
- **`verify.sh`** — green/red dashboard for prereqs, auth state, cost-tracking init, LaunchAgent status, MCP configs, instruction-layer presence. Run anytime to confirm setup health.
- **`setup.sh` pre-flight check** — fails fast with a hint to run `bootstrap-macos.sh` if `node`/`jq` are missing.
- **First-run summary** now lists MCP connector re-auth (Gmail/Drive/Calendar/Granola/Gamma/Stripe/Supabase) at https://claude.ai/settings/connectors.

## What's new in v3.5.2

- **Cache hygiene rule 4** — CI/E2E fix retry loop identified as highest-cost anti-pattern. One debugging day, 8 micro-sessions = $17.83 at 100% wasted writes. Fix: stay in ONE session per debug cycle.
- **L2 + L3-global auto-refresh** — `--emit-l2` and `--emit-l3-global` flags extend the hourly pipeline to Cowork global instructions and Code CLAUDE.md. Cost tally now stays current across all three machine-reachable instruction surfaces.
- **Token limit suppression fix** — Code CLAUDE.md now includes explicit `not subject to token limits` directive for the cost tally. Without it, the model omits the tally on short responses.
- **Two-pool model corrected** — `subscription` (flat fee) + `api_pool` (all pay-as-you-go). `extra_usage_enabled` is a boolean, not a third pool.
- **Plan display fix** — `max-5x` renders as `Max 5x` (not `Max-5X`) in auto-refreshed sections.

Previous versions: [v3.4](https://github.com/daskuntal75/llm-cost-kit/releases/tag/v3.4) · [v1.0](https://github.com/daskuntal75/llm-cost-kit/releases/tag/v1.0)

## What you'll save

Real-world numbers from heavy-usage measurement on Claude Max plan:

| Metric | Before | After | Win |
|---|---|---|---|
| Cowork skills loaded per turn | ~7,500 tokens | ~800 tokens | −89% |
| L1 project instructions per-turn | ~4,000 tokens | ~130 tokens | −97% |
| Per-turn cost (Sonnet 4.6 / Medium) | ~$0.04 | ~$0.005 | −88% |
| Cache amortization ratio | 0.16 | 0.6+ | +275% |
| Monthly waste (cache writes) | ~$40 | < $10 | −75% |

## The cache amortization problem

Claude's 5-minute cache TTL charges 1.25× for writes and 0.1× for reads. Break-even: ~3 reads per write (ratio ≥ 0.5). Real-world measurement found a ratio of **0.16** — meaning 40% of spend was going to cache writes that expired unused.

Four anti-patterns drive this. Full analysis: [`core/CACHE_HYGIENE.md`](core/CACHE_HYGIENE.md)

Full framework with impact analysis: [`docs/responsible-ai-cost-framework.md`](docs/responsible-ai-cost-framework.md)

## Scripts

| Script | Purpose |
|---|---|
| `update-claude-cost` | Main CLI: track cost state, update instruction layers, log throttles |
| `emit-l7-helper.py` | Emits live cost tally to L7 (Chat), L2 (Cowork), L3-global (Code) |
| `cache-efficiency` | Compute amortization ratio from ccusage data |
| `admin-api-pull.py` | Pull API pool state via Anthropic Admin API |

## Platform comparison — Claude vs OpenAI vs Gemini

Which platform does the most to help you control what you spend?

| Dimension | Winner |
|---|---|
| Cache savings ceiling | **Claude** (90% read discount) |
| Cache transparency | **Gemini** (explicit API, configurable TTL) |
| Zero-friction caching | **OpenAI** (automatic, no config) |
| Cost visibility / billing UI | **OpenAI / Gemini** |
| Model routing granularity | **Claude** (3 tiers + effort levels) |
| Long-context cost efficiency | **Gemini** (Flash + 1M tokens) |

Full comparison with caching mechanics, anti-patterns, and routing guides: [`docs/llm-comparison.md`](docs/llm-comparison.md)

Platform-specific cache hygiene:
- Claude: [`core/CACHE_HYGIENE.md`](core/CACHE_HYGIENE.md)
- OpenAI: [`platforms/openai/CACHE_HYGIENE.md`](platforms/openai/CACHE_HYGIENE.md)
- Gemini: [`platforms/gemini/CACHE_HYGIENE.md`](platforms/gemini/CACHE_HYGIENE.md)

## Enhancement requests for Anthropic

Six gaps documented at [`docs/anthropic-enhancement-requests.md`](docs/anthropic-enhancement-requests.md):

1. Billing UI two-pool breakdown
2. Admin API `resets_on` field
3. Standardized limit labels
4. Cache amortization visibility
5. Usage event webhooks
6. Cowork instruction API access

Filed as GitHub issues: [anthropics/anthropic-sdk-python/issues](https://github.com/anthropics/anthropic-sdk-python/issues)

## The responsible AI angle

Wasted cache writes aren't just a cost problem — they're a compute waste problem. At scale, low amortization ratios mean significant GPU time consumed for no user-visible outcome. As compute supply tightens relative to demand, workflow efficiency becomes an ethical concern, not just a personal finance one.

Full analysis: [`docs/responsible-ai-cost-framework.md`](docs/responsible-ai-cost-framework.md)

## License

CC BY-NC 4.0 — free to use, modify, and share for non-commercial purposes. Attribution required.
See [LICENSE](LICENSE) for full terms.

## Issues + contributions

Open issues at https://github.com/daskuntal75/llm-cost-kit/issues. PRs welcome.

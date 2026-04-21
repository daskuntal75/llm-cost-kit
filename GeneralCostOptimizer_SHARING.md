# Sharing Guide — llm-cost-kit

How to package and share the right kit for each recipient.

---

## The Three Share Scenarios

| Who's asking | What they get | Command to run |
|---|---|---|
| Claude user | `claude-cost-kit.zip` | `bash generate-kit.sh claude` |
| ChatGPT user | `openai-cost-kit.zip` | `bash generate-kit.sh openai` |
| Gemini user | `gemini-cost-kit.zip` | `bash generate-kit.sh gemini` |
| Multi-platform / DIY | `llm-cost-kit.zip` | `bash generate-kit.sh all` |

All outputs land in `dist/`. Each is self-contained — no dependency on the parent repo.

---

## Step 1 — One-time: set up the repo

```bash
git clone https://github.com/[your-username]/llm-cost-kit.git
cd llm-cost-kit
chmod +x generate-kit.sh
```

You only do this once. After that, every share is a single command.

---

## Step 2 — Generate the right kit

Run the command for what the recipient needs:

```bash
# Claude user
bash generate-kit.sh claude
# → dist/claude-cost-kit.zip

# ChatGPT / OpenAI user
bash generate-kit.sh openai
# → dist/openai-cost-kit.zip

# Gemini user
bash generate-kit.sh gemini
# → dist/gemini-cost-kit.zip

# Multi-platform or power user who'll self-configure
bash generate-kit.sh all
# → dist/llm-cost-kit.zip
```

Each command is idempotent — re-running regenerates the zip cleanly.

---

## Step 3 — Share the zip

Pick the channel that fits the relationship:

### Email or DM (1:1 share)

Attach `dist/<kit-name>.zip` directly. Suggested message:

> "Here's the cost optimization kit for [Claude/ChatGPT/Gemini] I mentioned.
> Unzip, run `bash setup.sh`, then open `guide.html` for the full walkthrough.
> The only file you need to edit is `config.yaml`."

### LinkedIn post (public share, broad reach)

1. Upload the zip to Google Drive or Dropbox → set to "Anyone with the link can view"
2. In your LinkedIn post, include the download link
3. Screenshot `guide.html` (open in browser) for the visual

**Suggested post hook:**
> "I reduced my Claude/ChatGPT/Gemini costs by 40–70% without changing what I ask
> for — just how the context is managed. Built this toolkit to share the system.
> Free download 👇"

### GitHub Releases (permanent, versioned, easy to update)

```bash
# Tag the release
git tag v1.0
git push origin v1.0

# Upload all generated kits to the release
gh release create v1.0 \
  dist/claude-cost-kit.zip \
  dist/openai-cost-kit.zip \
  dist/gemini-cost-kit.zip \
  dist/llm-cost-kit.zip \
  --title "v1.0 — Initial Release" \
  --notes "Platform-specific kits for Claude, OpenAI, and Gemini. Full kit includes all three."
```

Recipients get a direct download URL per kit:
```
https://github.com/[your-username]/llm-cost-kit/releases/download/v1.0/claude-cost-kit.zip
https://github.com/[your-username]/llm-cost-kit/releases/download/v1.0/openai-cost-kit.zip
https://github.com/[your-username]/llm-cost-kit/releases/download/v1.0/gemini-cost-kit.zip
https://github.com/[your-username]/llm-cost-kit/releases/download/v1.0/llm-cost-kit.zip
```

Share the URL that matches what the recipient uses. Or link to the full Releases page and let them pick.

### GitHub Pages (shareable web guide, zero friction)

```bash
# Copy guide.html to a gh-pages branch
git checkout --orphan gh-pages
cp guide.html index.html
git add index.html
git commit -m "Add guide"
git push origin gh-pages
```

Your guide is now live at:
```
https://[your-username].github.io/llm-cost-kit/
```

Share this URL in LinkedIn posts, bios, and emails. Recipients can read the guide in
the browser and download the relevant kit from your Releases page.

---

## What each kit contains

### `claude-cost-kit.zip` (Claude-only)

```
claude-cost-kit/
├── README.md                  ← Claude-specific instructions
├── config.yaml                ← Pre-configured for Claude only
├── setup.sh                   ← Installs Claude Code, ccusage, MCP configs, aliases
├── guide.html                 ← Full interactive guide
├── core/
│   ├── PRINCIPLES.md
│   ├── OUTPUT_RULES.md
│   └── SESSION_HYGIENE.md
└── platforms/
    └── claude/
        ├── CLAUDE.md
        ├── SKILL.md
        └── mcp-configs/
            ├── mcp-saas.json
            ├── mcp-work.json
            ├── mcp-infra.json
            └── mcp-default.json
```

### `openai-cost-kit.zip` (OpenAI-only)

```
openai-cost-kit/
├── README.md                  ← OpenAI-specific instructions
├── config.yaml                ← Pre-configured for OpenAI only
├── setup.sh                   ← Installs openai package, sets API key
├── guide.html
├── core/
│   ├── PRINCIPLES.md
│   ├── OUTPUT_RULES.md
│   └── SESSION_HYGIENE.md
└── platforms/
    └── openai/
        ├── README.md
        └── SYSTEM_PROMPT.md   ← Paste into ChatGPT Projects / Custom GPTs
```

### `gemini-cost-kit.zip` (Gemini-only)

```
gemini-cost-kit/
├── README.md                  ← Gemini-specific instructions
├── config.yaml                ← Pre-configured for Gemini only
├── setup.sh                   ← Installs google-generativeai, sets API key
├── guide.html
├── core/
│   ├── PRINCIPLES.md
│   ├── OUTPUT_RULES.md
│   └── SESSION_HYGIENE.md
└── platforms/
    └── gemini/
        ├── README.md
        └── GEM_INSTRUCTIONS.md ← Paste into Gem builder / AI Studio
```

### `llm-cost-kit.zip` (Full kit — all platforms)

```
llm-cost-kit/
├── README.md                  ← Full multi-platform instructions
├── config.yaml                ← All platforms listed; user uncomments what they use
├── setup.sh                   ← Unified wizard — reads config.yaml
├── guide.html
├── core/
│   ├── PRINCIPLES.md
│   ├── OUTPUT_RULES.md
│   └── SESSION_HYGIENE.md
└── platforms/
    ├── claude/                ← Full Claude adapter
    ├── openai/                ← Full OpenAI adapter
    └── gemini/                ← Full Gemini adapter
```

---

## Updating and re-sharing

When the kit changes (new Claude model version, new MCP server URL, etc.):

```bash
# Edit the relevant file in platforms/ or core/
# Then regenerate just the affected kits:
bash generate-kit.sh claude
bash generate-kit.sh all

# Bump the GitHub release
gh release create v1.1 \
  dist/claude-cost-kit.zip \
  dist/llm-cost-kit.zip \
  --title "v1.1 — Updated model names"
```

Recipients who downloaded a direct release URL always have the version they downloaded.
Anyone who bookmarked the Releases page will see the latest.

---

## Quick decision tree

```
Does the recipient know which LLM they use?
│
├── Yes — Claude only         → bash generate-kit.sh claude
│
├── Yes — ChatGPT / OpenAI    → bash generate-kit.sh openai
│
├── Yes — Gemini              → bash generate-kit.sh gemini
│
├── Yes — multiple platforms  → bash generate-kit.sh all
│
└── No / unclear              → bash generate-kit.sh all
                                (full kit — they pick what applies)
```

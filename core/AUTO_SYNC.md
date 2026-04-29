# Auto-Sync Architecture (fswatch + GitHub)

The cost-optimization stack is itself a maintenance problem: skills, instructions across 7 layers, MCP configs, and per-project CLAUDE.md files. Without automation, edits drift.

This guide describes the auto-sync pattern: a single source-of-truth repo, file-watcher that auto-commits, and symlinks from consumer locations.

---

## The pattern in one sentence

**Edit any file in `~/dev/skills-source/`, save it, GitHub has it 5 seconds later.**

---

## Architecture

```
~/dev/skills-source/                    ← single source of truth (private GitHub repo)
├── skills/                             ← canonical skill source
│   ├── cost-optimizer/SKILL.md
│   ├── memory-first/SKILL.md
│   └── status-rollup/SKILL.md
├── cowork-instructions/                ← L1 + L2 templates
│   ├── _global.md                      (L2)
│   ├── project-a.md                  (L1)
│   └── project-b.md                     (L1)
├── chat-instructions/                  ← L7 templates (one per Chat project)
├── claude-md/                          ← L3 templates (one per Code project)
├── mcp-configs/                        ← MCP server JSON configs
├── user-preferences.md                 ← L4 template
├── scripts/
│   ├── start-watcher.sh                ← fswatch entry point
│   ├── sync.sh                         ← branched sync logic
│   ├── build-skills.sh                 ← rebuilds .skill zips
│   ├── init-git.sh                     ← first-time repo setup
│   └── watcher-launchagent.sh          ← installs LaunchAgent plist
└── .build/
    ├── *.skill                         ← generated zips
    ├── sync-debug.log
    └── watcher-debug.log
```

Symlinks from consumer locations:
- `~/.claude/skills/<n>.skill` → `~/dev/skills-source/.build/<n>.skill`
- `~/.agents/skills/<n>.skill` → `~/dev/skills-source/.build/<n>.skill`
- `~/<project-repo>/CLAUDE.md` → `~/dev/skills-source/claude-md/<project>.md`

---

## How the watcher works

A LaunchAgent runs `start-watcher.sh` at login + keep-alive. It uses `fswatch` to monitor 6 paths:
- `skills/`
- `cowork-instructions/`
- `chat-instructions/`
- `claude-md/`
- `mcp-configs/`
- `user-preferences.md`

When a file changes:

1. **fswatch fires** (debounced 2s — multiple saves batched)
2. **`sync.sh` runs**:
   - If change is in `skills/` → run `build-skills.sh` to rebuild `.skill` zips
   - Always: `git add -A`, `git commit`, `git push`
3. **GitHub has the change ~5 seconds after save**

Other machines `git pull` to sync. The Mac Mini (or any future machine) clones once and stays in sync via pull.

---

## Critical implementation details (gotchas)

### 1. LaunchAgents run with bare PATH

System binaries like `date`, `zip`, `git` may not be on the LaunchAgent's PATH. Three options:

| Option | When to use |
|---|---|
| Use absolute paths (`/bin/date`, `/usr/bin/zip`) | Best for consistency |
| Add `export PATH=...` at top of sync.sh | Works for any tool |
| Both (belt + suspenders) | Recommended |

The reference `sync.sh` does both:

```bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH
exec >> "$DEBUG_LOG" 2>&1
```

### 2. Don't use `--one-per-batch` flag for fswatch

That flag returns a count (`1`, `2`) instead of actual filepaths. Without filepath info, branching logic (skill vs non-skill) can't work.

### 3. Production app repos must `.gitignore` symlinked CLAUDE.md

When you symlink `~/your-app/CLAUDE.md` to skills-source, add `CLAUDE.md*` to your app's `.gitignore` so the symlink doesn't get committed. Wildcard suffix covers backup files like `CLAUDE.md.v1-backup`.

### 4. The skills-source repo is private

It contains your personal context (project names, security rules, business metrics). Keep it private. The public-facing kit (this kit) is sanitized templates only.

---

## Setup sequence

The `setup.sh` in this kit handles steps 1–4 below automatically. Steps 5–6 require manual UI work in Claude Desktop App.

1. Create `~/dev/skills-source/` (or your chosen path) with the structure above
2. Initialize git, add a private GitHub remote
3. Copy template files from this kit into the structure
4. Install fswatch + LaunchAgent + scripts
5. Manually populate L2 + L1 + L4 + L7 instructions (templates provided)
6. Set up symlinks from `~/.claude/skills/` → `.build/` and from project repos → `claude-md/`

---

## What this gives you

- Single edit point for all instructions
- Auto-versioned in git
- Multi-machine sync via `git pull`
- Watcher catches edits regardless of editor (vim, VS Code, Sublime)
- Build step only runs when needed (skill change), not on every save

---

## Troubleshooting

| Symptom | Diagnosis |
|---|---|
| Edit doesn't trigger commit | Check `~/dev/skills-source/.build/watcher-debug.log` |
| Commit happens but build fails (exit 127) | PATH issue — verify `export PATH=...` in sync.sh |
| Wrong filepath in commit message | `--one-per-batch` flag still in start-watcher.sh — remove it |
| Watcher process not running | `launchctl list \| grep skills-watcher` — should show PID |
| Stale .skill zips | `bash ~/dev/skills-source/scripts/build-skills.sh` to force rebuild |


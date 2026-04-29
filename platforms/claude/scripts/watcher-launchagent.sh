#!/bin/zsh
# =============================================================================
# watcher-launchagent.sh — Install + load the skills-watcher LaunchAgent
# Idempotent.
# =============================================================================

SOURCE_ROOT=~/dev/skills-source       # ← change if your skills-source lives elsewhere
PLIST=~/Library/LaunchAgents/com.YOURUSER.skills-watcher.plist

# (Replace "YOURUSER" in the Label below with your own identifier if you fork this)

cat > "$PLIST" << PLISTCONTENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.YOURUSER.skills-watcher</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>$SOURCE_ROOT/scripts/start-watcher.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$SOURCE_ROOT/.build/watcher.log</string>
  <key>StandardErrorPath</key>
  <string>$SOURCE_ROOT/.build/watcher.err</string>
</dict>
</plist>
PLISTCONTENT

# Load it
launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"
sleep 2

if launchctl list | grep -q skills-watcher; then
  PID=$(launchctl list | grep skills-watcher | awk '{print $1}')
  echo "✓ skills-watcher LaunchAgent loaded (PID $PID)"
else
  echo "✗ Failed to load LaunchAgent. Check $SOURCE_ROOT/.build/watcher.err"
  exit 1
fi

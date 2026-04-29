#!/bin/zsh
# Install LaunchAgent to refresh Code spend daily
# Idempotent.

PLIST=~/Library/LaunchAgents/com.YOURUSER.cumulative-cost.plist
SCRIPT_PATH=~/.local/bin/update-claude-cost
# (Replace "YOURUSER" in the Label with your own identifier if forking)

cat > "$PLIST" << PLISTCONTENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.YOURUSER.cumulative-cost</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>$SCRIPT_PATH --code</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>8</integer>
    <key>Minute</key>
    <integer>30</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>/tmp/cumulative-cost.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/cumulative-cost.err</string>
</dict>
</plist>
PLISTCONTENT

launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"
echo "✓ Cumulative cost LaunchAgent installed (fires daily at 8:30 AM)"

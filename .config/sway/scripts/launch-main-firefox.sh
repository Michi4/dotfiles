#!/bin/bash
# launch-main-firefox.sh - Launch main collaboration Firefox window (visible, not stash)
# Tabs: Zulip + Vikunja + Support + AI Studio
# This window stays visible (workspace 1), NOT in scratchpad.
# Idempotent: if main window already exists (by URL), just ensure it's visible, don't duplicate.

set -e

MAIN_URLS=(
  "https://collaboration.koerbler.com/#inbox"
  "https://vikunja.bwh.at/"
  "https://support.brunner.at/"
  "https://aistudio.google.com/"
)

# Check if we already have a main window (check via sessionstore or sway tree for Zulip/Vikunja)
# Use sway tree check + sessionstore check via lz4 if available
NEEDS_LAUNCH=true

if command -v lz4 >/dev/null 2>&1 && [ -f "/home/michi/.mozilla/firefox/5446foem.default-release-1778515419450/sessionstore-backups/recovery.jsonlz4" ]; then
  # Try to parse sessionstore quickly via lz4 payload if python lz4 available
  if python3 -c "import lz4.block" 2>/dev/null; then
    HAS_MAIN=$(python3 << 'PY' 2>/dev/null
import lz4.block, json, glob
try:
  data=open('/home/michi/.mozilla/firefox/5446foem.default-release-1778515419450/sessionstore-backups/recovery.jsonlz4','rb').read()
  payload=data[8:]
  decom=lz4.block.decompress(payload)
  j=json.loads(decom)
  found=False
  for w in j.get('windows',[]):
    urls=[e['url'] for t in w.get('tabs',[]) for e in t.get('entries',[]) ]
    # Check if window contains at least 2 of main URLs
    main_count=sum(1 for u in urls if 'collaboration.koerbler.com' in u or 'vikunja.bwh.at' in u or 'support.brunner.at' in u)
    if main_count>=2:
      found=True
      break
  print("1" if found else "0")
except:
  print("0")
PY
)
    if [ "$HAS_MAIN" = "1" ]; then
      NEEDS_LAUNCH=false
    fi
  fi
fi

# Fallback: check sway tree for Zulip/Vikunja titles if python check failed
if [ "$NEEDS_LAUNCH" = "true" ] && swaymsg -t get_tree 2>/dev/null | grep -q "Zulip\|Vikunja\|support.brunner"; then
  # If sway already has main window visible, don't launch duplicate
  # But sway title depends on active tab; check more robustly via sessionstore already did
  # If we are here, we already checked sessionstore, so still need launch if sway check fails
  true
fi

if [ "$NEEDS_LAUNCH" = "false" ]; then
  # Ensure main window is not in scratchpad (in case it was stashed)
  swaymsg '[app_id="firefox" title=".*Zulip.*"] move container to workspace number 1' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*Vikunja.*"] move container to workspace number 1' >/dev/null 2>&1 || true
  notify-send "Main ready" "Zulip • Vikunja • Support • AI Studio (already open)" 2>/dev/null || true
  exit 0
fi

# Launch main window
MOZ_ENABLE_WAYLAND=1 firefox --new-window "${MAIN_URLS[@]}" &
# Optional: bring to workspace 1 after a moment
sleep 2
swaymsg '[app_id="firefox" title=".*Zulip.*"] move container to workspace number 1' >/dev/null 2>&1 || true
swaymsg '[app_id="firefox" title=".*Vikunja.*"] move container to workspace number 1' >/dev/null 2>&1 || true
notify-send "Main ready" "Zulip • Vikunja • Support • AI Studio (workspace 1)" 2>/dev/null || true

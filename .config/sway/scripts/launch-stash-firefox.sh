#!/bin/bash
# launch-stash-firefox.sh - Launch stash Firefox window and move to scratchpad
# Tabs: WhatsApp + Kimai + ManagedWP (InfiniteWP) + HedgeDoc (md.home.websters.at)
# Toggle: $mod+minus (show/hide), $mod+Shift+minus (send to stash)
# Part of sway autostart - separate window from main collab window (Zulip/Vikunja/Support/AI Studio)

set -e

STASH_URLS=(
  "https://web.whatsapp.com/"
  "https://kimai.bwh.at/en/timesheet/"
  "https://managedwp.at/iwp/v3/login.php"
  "https://md.home.websters.at/8eR4VIQzQcCNgD64lifkDQ?both"
)

# Idempotent: if stash window already exists (check sessionstore), just ensure it's in scratchpad
if command -v lz4 >/dev/null 2>&1 && python3 -c "import lz4.block" 2>/dev/null; then
  HAS_STASH=$(python3 << 'PY' 2>/dev/null
import lz4.block, json
try:
  data=open('/home/michi/.mozilla/firefox/5446foem.default-release-1778515419450/sessionstore-backups/recovery.jsonlz4','rb').read()
  payload=data[8:]
  decom=lz4.block.decompress(payload)
  j=json.loads(decom)
  found=False
  for w in j.get('windows',[]):
    urls=[e['url'] for t in w.get('tabs',[]) for e in t.get('entries',[]) ]
    stash_count=sum(1 for u in urls if 'web.whatsapp.com' in u or 'kimai.bwh.at' in u or 'managedwp.at' in u)
    if stash_count>=2:
      found=True
      break
  print("1" if found else "0")
except:
  print("0")
PY
)
  if [ "$HAS_STASH" = "1" ]; then
    # Ensure stash window is in scratchpad (move by title)
    for i in 1 2 3; do
      sleep 0.5
      swaymsg '[app_id="firefox" title=".*WhatsApp.*"] move scratchpad' >/dev/null 2>&1 || true
      swaymsg '[app_id="firefox" title=".*Kimai.*"] move scratchpad' >/dev/null 2>&1 || true
      swaymsg '[app_id="firefox" title=".*InfiniteWP.*"] move scratchpad' >/dev/null 2>&1 || true
      swaymsg '[app_id="firefox" title=".*HedgeDoc.*"] move scratchpad' >/dev/null 2>&1 || true
    done
    notify-send "Stash ready" "WhatsApp • Kimai • ManagedWP • HedgeDoc already in stash (Mod+ -)" 2>/dev/null || true
    exit 0
  fi
fi

# Give main Firefox window time to start first (avoid race)
sleep 1.5

# Launch stash window - --new-window ensures separate window in same Firefox process
MOZ_ENABLE_WAYLAND=1 firefox --new-window "${STASH_URLS[@]}" &

# Wait for window to appear and ensure it lands in scratchpad (for_window may already do it, but do it robustly)
for i in {1..12}; do
  sleep 1
  swaymsg '[app_id="firefox" title=".*WhatsApp.*"] move scratchpad' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*Kimai.*"] move scratchpad' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*InfiniteWP.*"] move scratchpad' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*ManagedWP.*"] move scratchpad' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*HedgeDoc.*"] move scratchpad' >/dev/null 2>&1 || true
  swaymsg '[app_id="firefox" title=".*websters.*"] move scratchpad' >/dev/null 2>&1 || true
  if [ "$i" -gt 4 ] && swaymsg -t get_tree 2>/dev/null | grep -q "WhatsApp\|Kimai\|InfiniteWP"; then
    break
  fi
done

notify-send "Stash ready" "WhatsApp • Kimai • ManagedWP • HedgeDoc in stash (Mod+ - to toggle)" 2>/dev/null || true

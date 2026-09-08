#!/bin/bash
# launch-mattermost-stash.sh - Stash the Mattermost MAIN window ONCE at startup.
# Deliberately NOT a for_window rule: a blanket rule would also swallow
# call-widget / incoming-call windows the moment they open. Windows opened
# later (calls) stay visible; stash manually with $mod+Shift+minus if needed.
set -e

# Call-ish titles that must NEVER be auto-stashed (case-insensitive match in python)
for i in $(seq 1 80); do
  sleep 0.5
  FOUND=$(swaymsg -t get_tree 2>/dev/null | python3 -c "
import json,sys
try:
  t=json.load(sys.stdin)
except Exception:
  sys.exit(0)
bad=('call','ringing','incoming','outgoing','dial','widget','share','pop-out','popout')
def walk(n):
  if n.get('app_id')=='Mattermost.Desktop' and n.get('type') in ('con','floating_con'):
    name=(n.get('name') or '').lower()
    if 'mattermost' in name and not any(b in name for b in bad) and n.get('scratchpad_state','none')=='none':
      print(n.get('id'))
      return True
  for c in n.get('nodes',[])+n.get('floating_nodes',[]):
    if walk(c): return True
  return False
walk(t)
")
  if [ -n "$FOUND" ]; then
    swaymsg "[con_id=$FOUND] move scratchpad" >/dev/null 2>&1 || true
    notify-send "Mattermost stashed" "Main window in stash (Mod+ - to toggle). Call windows stay visible." 2>/dev/null || true
    exit 0
  fi
  # stop waiting if mattermost isn't even starting (autostart disabled etc.)
  if [ "$i" -gt 20 ] && ! pgrep -f "mattermost-desktop" >/dev/null 2>&1; then
    exit 0
  fi
done

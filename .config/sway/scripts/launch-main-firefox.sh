#!/bin/bash
# launch-main-firefox.sh - Ensure main collaboration Firefox window is visible on workspace 5.
# Tabs: Zulip + Support + AI Studio + Nextcloud calendar + deadman-z + SSO apps + Offi docs
# Design: Firefox restores the session (browser.startup.page=3); this script only
#   1. repairs a split/duplicated session via merge-firefox-windows.py (only when Firefox is NOT running),
#   2. starts Firefox if needed (restore, or fresh --new-window fallback on a blank profile),
#   3. moves the main window to workspace 5.
# NOTE: Vikunja belongs to the STASH window - never match it here (would steal the stash window).

set -e

MAIN_URLS=(
  "https://collaboration.koerbler.com/#inbox"
  "https://support.brunner.at/"
  "https://aistudio.google.com/library"
  "https://cloud9.proserver1.at/index.php/apps/calendar/"
  "https://deadman-z.monit.apronix.net/"
  "https://sso.proserver1-auth.at/ui/apps"
  "https://docs.offi.apronix.net/"
)
SESSIONSTORE="/home/michi/.mozilla/firefox/5446foem.default-release-1778515419450/sessionstore-backups/recovery.jsonlz4"
MERGE="$HOME/.config/sway/scripts/merge-firefox-windows.py"

firefox_running() {
  pgrep -x firefox >/dev/null 2>&1 || swaymsg -t get_tree 2>/dev/null | grep -q '"app_id":"firefox"'
}

move_main_to_ws1() {
  for i in 1 2 3 4 5 6; do
    sleep 1
    swaymsg '[app_id="firefox" title=".*Zulip.*"] move container to workspace number 5' >/dev/null 2>&1 || true
    swaymsg '[app_id="firefox" title=".*Helpdesk.*"] move container to workspace number 5' >/dev/null 2>&1 || true
    swaymsg '[app_id="firefox" title=".*support\.brunner.*"] move container to workspace number 5' >/dev/null 2>&1 || true
    swaymsg '[app_id="firefox" title=".*AI Studio.*"] move container to workspace number 5' >/dev/null 2>&1 || true
    swaymsg '[app_id="firefox" title=".*collaboration\.koerbler.*"] move container to workspace number 5' >/dev/null 2>&1 || true
  done
}

if firefox_running; then
  move_main_to_ws1
  notify-send "Main ready" "Support • Zulip • AI Studio • Calendar • deadman-z • SSO • Docs (workspace 5)" 2>/dev/null || true
  exit 0
fi

# Firefox not running: repair split sessions first (no-op if already canonical)
if [ -f "$SESSIONSTORE" ] && [ -x "$MERGE" ] && python3 -c "import lz4.block" 2>/dev/null; then
  python3 "$MERGE" "$SESSIONSTORE" >/dev/null 2>&1 || true
fi

# Restore merged session; fresh --new-window fallback only on a blank profile
HAS_MAIN=false
if [ -f "$SESSIONSTORE" ] && python3 -c "import lz4.block" 2>/dev/null; then
  HAS_MAIN=$(python3 -c "
import lz4.block, json
try:
  j=json.loads(lz4.block.decompress(open('$SESSIONSTORE','rb').read()[8:]))
  urls=[e['url'] for w in j.get('windows',[]) for t in w.get('tabs',[]) for e in t.get('entries',[])]
  print('1' if any('support.brunner.at' in u or 'collaboration.koerbler.com' in u or 'aistudio.google.com' in u for u in urls) else '0')
except Exception:
  print('0')
" 2>/dev/null || echo "0")
  [ "$HAS_MAIN" = "1" ] && HAS_MAIN=true || HAS_MAIN=false
fi

if [ "$HAS_MAIN" = true ]; then
  MOZ_ENABLE_WAYLAND=1 firefox &
else
  MOZ_ENABLE_WAYLAND=1 firefox --new-window "${MAIN_URLS[@]}" &
fi

move_main_to_ws1
notify-send "Main ready" "Support • Zulip • AI Studio • Calendar • deadman-z • SSO • Docs (workspace 5)" 2>/dev/null || true

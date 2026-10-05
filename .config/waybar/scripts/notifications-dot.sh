#!/usr/bin/env bash
# Tiny red-dot indicator for pending/missed notifications (waybar module).
# Reads the clock's cache: zero extra mako calls. Empty output when clean,
# so with zero padding the module takes no space at all.
cache="/tmp/waybar-clock-notifs"
seen_file="/tmp/waybar-clock-seen"
read -r vis maxid hcount < "$cache" 2>/dev/null
[ -z "$vis" ] && vis=0
[ -z "$maxid" ] && maxid=0
[ -z "$hcount" ] && hcount=0
seen=$(cat "$seen_file" 2>/dev/null || echo 0)
[ -z "$seen" ] && seen=0

if [ "$hcount" -gt 0 ] 2>/dev/null && \
   { [ "$vis" -gt 0 ] 2>/dev/null || [ "$maxid" -gt "$seen" ] 2>/dev/null; }; then
  text="<span color='#bf616a'>●</span> <small>$hcount</small>"
  tip="$hcount notification(s) - click to manage"
  echo "{\"text\":\"$text\",\"tooltip\":\"$tip\",\"class\":\"notified\"}"
else
  echo '{"text":"","tooltip":"missed notifications live here","class":""}'
fi

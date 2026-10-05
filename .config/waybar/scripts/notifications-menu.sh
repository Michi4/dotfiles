#!/usr/bin/env bash
# wofi notification center for the waybar clock (middle-click).
# Pick a row to dismiss exactly that notification; opening marks all seen.
seen_file="/tmp/waybar-clock-seen"

hist_json=$(makoctl history -j 2>/dev/null || echo '[]')
hcount=$(jq 'length' <<< "$hist_json" 2>/dev/null || echo 0)
if [ -z "$hcount" ] || [ "$hcount" -eq 0 ]; then
  notify-send "Notifications" "Nothing here" 2>/dev/null
  exit 0
fi

# opening the menu = you saw them -> dot goes out (unless new ones arrive)
jq -r '[.[].id] | max // 0' <<< "$hist_json" > "$seen_file" 2>/dev/null

menu=$(jq -r 'reverse | .[] | "\(.id) │ \(.app_name // "?"): \(.summary // "")"' <<< "$hist_json" 2>/dev/null)
menu="$menu"$'\n'"x dismiss ALL"
pick=$(printf '%s\n' "$menu" | wofi --dmenu -p "Notifications (pick to dismiss)" --lines 12)
[ -z "$pick" ] && exit 0

if [ "$pick" = "x dismiss ALL" ]; then
  makoctl dismiss --all 2>/dev/null
else
  id="${pick%%│*}"
  [ -n "$id" ] && makoctl dismiss -n "$id" 2>/dev/null
fi

# force the clock to re-render within its next tick
rm -f /tmp/waybar-clock-notifs

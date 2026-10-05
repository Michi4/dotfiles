#!/usr/bin/env bash
# Notification center for the waybar clock (middle-click).
# Stays open until you Escape; picking a row dismisses exactly that one.
seen_file="/tmp/waybar-clock-seen"
style="$HOME/.config/wofi/notifications.css"

# force clock + dot to re-render within their next tick
refresh() { rm -f /tmp/waybar-clock-notifs; pkill -RTMIN+15 waybar 2>/dev/null || true; }

while true; do
  hist_json=$(makoctl history -j 2>/dev/null || echo '[]')
  hcount=$(jq 'length' <<< "$hist_json" 2>/dev/null || echo 0)
  if [ -z "$hcount" ] || [ "$hcount" -eq 0 ]; then
    notify-send "Notifications" "All clear" 2>/dev/null
    exit 0
  fi

  # opening/refreshing = you saw them -> red dot goes out
  jq -r '[.[].id] | max // 0' <<< "$hist_json" > "$seen_file" 2>/dev/null
  rm -f /tmp/waybar-clock-notifs

  rows=$(jq -r 'reverse | .[] | "<b>\(.app_name // "?" | @html)</b>: \(.summary // "" | @html) <small>\(.body // "" | .[0:80] | @html)</small> <span size='"'"'1'"'"' color='"'"'#2e3440'"'"'>ID:\(.id)</span>"' <<< "$hist_json" 2>/dev/null)
  rows="$rows"$'\n'"<b>x dismiss ALL</b>"

  pick=$(printf '%s\n' "$rows" | wofi --dmenu --allow-markup \
    --style "$style" --location top_right --xoffset -12 --yoffset 38 \
    --width 620 --lines 12 --prompt "Notifications")
  [ -z "$pick" ] && exit 0

  id=$(grep -oE 'ID:[0-9]+' <<< "$pick" | cut -d: -f2)
  if [ -n "$id" ]; then
    makoctl dismiss -n "$id" 2>/dev/null
    refresh
  else
    makoctl dismiss --all 2>/dev/null
    refresh
    exit 0
  fi
done

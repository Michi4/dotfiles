#!/usr/bin/env bash
today_d=$(date +%-d)
today_m=$(date +%-m)
today_y=$(date +%Y)

cal_out=$(cal -m "$today_m" "$today_y")

# Center each calendar line within the widest line
maxw=0
while IFS= read -r line; do
  w=${#line}
  [ "$w" -gt "$maxw" ] && maxw=$w
done <<< "$cal_out"

cal_centered=""
while IFS= read -r line; do
  w=${#line}
  pad=$(( (maxw - w) / 2 ))
  cal_centered+="$(printf '%*s' "$pad" '')${line}"$'\n'
done <<< "$cal_out"

# Highlight today's date: bright yellow, bold, single underline
cal_hl=$(echo "$cal_centered" | sed -E "s/(^|[^0-9])($today_d)([^0-9]|$)/\1<span color='#ebcb8b' font_weight='bold' underline='single'>\2<\/span>\3/g")

nl=$'\n'

# Notifications below the calendar (cached 5s; cheap next to the calendar work).
notif_cache="/tmp/waybar-clock-notifs"
cache_age=999
if [ -f "$notif_cache" ]; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$notif_cache" 2>/dev/null || echo 0) ))
fi
if [ "$cache_age" -gt 5 ]; then
  ncount=$(makoctl list -j 2>/dev/null | jq 'length' 2>/dev/null)
  [ -z "$ncount" ] && ncount=0
  {
    echo "$ncount"
    if [ "$ncount" -gt 0 ] 2>/dev/null; then
      echo "<b>Notifications ($ncount)</b>"
      makoctl history -j 2>/dev/null | jq -r 'reverse | .[0:5] | .[] | "<b><span color=\"#81a1c1\">\(.app_name // "Notification" | @html)</span></b>: \(.summary | @html)\n<small><span color=\"#9aa0a6\">\(.body // "" | .[0:200] | @html)</span></small>"' 2>/dev/null
      echo "<small><span color='#4c566a'>right-click to view / dismiss</span></small>"
    else
      echo "<span color='#4c566a'>No new notifications</span>"
    fi
  } > "$notif_cache"
fi
ncount=$(sed -n '1p' "$notif_cache")
notif_section=$(tail -n +2 "$notif_cache")
notif_class=""
[ "${ncount:-0}" -gt 0 ] 2>/dev/null && notif_class="notified"

header="<b>$(date '+%a %d %b %Y  %H:%M:%S')</b>"
tooltip="${header}${nl}${nl}<tt><span font='monospace 13' font_weight='bold'>${cal_hl}</span></tt>"
tooltip="${tooltip}${nl}<span color='#4c566a'>────────────────</span>${nl}${notif_section}"

text=$(date '+%a %d %b %H:%M')
jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$notif_class" '{"text":$text,"tooltip":$tooltip,"class":$class}'

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
# Section = mako HISTORY (the missed-notifications record); the dot means
# live popups (visible) OR history newer than last menu visit (seen-file).
notif_cache="/tmp/waybar-clock-notifs"
seen_file="/tmp/waybar-clock-seen"
cache_age=999
if [ -f "$notif_cache" ]; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$notif_cache" 2>/dev/null || echo 0) ))
fi
if [ "$cache_age" -gt 5 ]; then
  hist_json=$(makoctl history -j 2>/dev/null || echo '[]')
  vis=$(makoctl list -j 2>/dev/null | jq 'length' 2>/dev/null)
  [ -z "$vis" ] && vis=0
  hcount=$(jq 'length' <<< "$hist_json" 2>/dev/null)
  [ -z "$hcount" ] && hcount=0
  maxid=$(jq '[.[].id] | max // 0' <<< "$hist_json" 2>/dev/null)
  [ -z "$maxid" ] && maxid=0
  {
    echo "$vis $maxid $hcount"
    if [ "$hcount" -gt 0 ] 2>/dev/null; then
      echo "<b>Notifications ($hcount)</b>"
      jq -r 'reverse | .[0:6] | map("<span background=\"#2e3440\"> <b><span color=\"#81a1c1\">\(.app_name // "Notification" | @html)</span></b>: \(.summary | @html)\n <small><span color=\"#9aa0a6\">\(.body // "" | .[0:200] | @html)</span></small> </span>") | join("\n\n")' <<< "$hist_json" 2>/dev/null
      echo "<small><span color='#4c566a'>middle-click to dismiss</span></small>"
    else
      echo "<span color='#4c566a'>No new notifications</span>"
    fi
  } > "$notif_cache"
fi
read -r vis maxid hcount < "$notif_cache" 2>/dev/null
[ -z "$vis" ] && vis=0
[ -z "$maxid" ] && maxid=0
[ -z "$hcount" ] && hcount=0
seen=$(cat "$seen_file" 2>/dev/null || echo 0)
[ -z "$seen" ] && seen=0
notif_section=$(tail -n +2 "$notif_cache")
notif_class=""
if [ "$vis" -gt 0 ] 2>/dev/null || [ "$maxid" -gt "$seen" ] 2>/dev/null; then
  notif_class="notified"
fi

header="<b>$(date '+%a %d %b %Y  %H:%M:%S')</b>"
tooltip="${header}${nl}${nl}<tt><span font='monospace 13' font_weight='bold'>${cal_hl}</span></tt>"
tooltip="${tooltip}${nl}<span color='#4c566a'>────────────────</span>${nl}${notif_section}"

text=$(date '+%a %d %b %H:%M')
jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$notif_class" '{"text":$text,"tooltip":$tooltip,"class":$class}'

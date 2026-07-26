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
header="<b>$(date '+%a %d %b %Y  %H:%M:%S')</b>"
tooltip="${header}${nl}${nl}<tt><span font='monospace 13' font_weight='bold'>${cal_hl}</span></tt>"

text=$(date '+%a %d %b %H:%M')
jq -nc --arg text "$text" --arg tooltip "$tooltip" '{"text":$text,"tooltip":$tooltip}'

#!/usr/bin/env bash
# Single-shot mako status for waybar (polled via interval + SIGRTMIN+14).
count=$(makoctl list -j 2>/dev/null | jq 'length' || echo 0)

if [ "$count" -eq 0 ]; then
  text=" 0"
  class="none"
else
  text=" $count"
  class="active"
fi

history=$(makoctl history -j 2>/dev/null | jq -r 'reverse | .[0:5] | map("<b>\(.app_name // "Notification" | @html)</b>: \(.summary | @html)\n<small>\(.body // "" | @html)</small>") | join("\n\n")')

if [ -z "$history" ]; then
  history="No recent notifications"
fi

tooltip="History:\n\n$history"

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" '{"text": $text, "tooltip": $tooltip, "class": $class}'

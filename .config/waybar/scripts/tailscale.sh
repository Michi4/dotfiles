#!/usr/bin/env bash
# Single-shot tailscale status for waybar (interval-polled).
# text: peers online (exit node marked); tooltip: full status table.
out=$(tailscale status 2>/dev/null)
if [ -z "$out" ]; then
  echo '{"text":"󰖂 off","tooltip":"tailscaled unreachable","class":"down"}'
  exit 0
fi
total=$(grep -cE '^[0-9]+\.[0-9]+|^\s+\("' <<< "$out")
offline=$(grep -c "offline" <<< "$out" || true)
online=$((total - offline))
[ -z "$online" ] && online=0
me=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<< "$out" | head -1 | awk '{print $1, $2}')
exitnode=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('ExitNodeOption',{}) and 'exit' or '')" 2>/dev/null)
text="󰖂 $online/$total"
cls="up"
[ "$online" -eq 0 ] && cls="down"
[ -n "$exitnode" ] && { text="$text exit"; cls="exit"; }
tip=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<< "$out")
tip="this: $me${exitnode:+ (exit node on)}\n\n$tip"
jq -nc --arg text "$text" --arg tooltip "$tip" --arg class "$cls" '{"text":$text,"tooltip":$tooltip,"class":$class}'

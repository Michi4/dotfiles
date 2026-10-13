#!/usr/bin/env bash
# Change the volume of the player shown in waybar slot <idx>.
# Called by waybar on-scroll-up/down on the custom/media-N modules.
# Usage: media-volume.sh <idx> <up|down>
idx=${1:-0}
dir=${2:-up}
cache="/tmp/waybar-media-cache-$idx.txt"
volshow="/tmp/waybar-media-volshow-$idx.txt"
sig=$((8 + idx))

[ -f "$cache" ] || exit 0
player=$(sed -n '1p' "$cache")
[ -n "$player" ] || exit 0
vol=$(playerctl -p "$player" volume 2>/dev/null) || exit 0

if [ "$dir" = "up" ]; then
  new=$(awk -v v="$vol" 'BEGIN{n=v+0.05; if(n>1.0)n=1.0; printf "%.4f", n}')
else
  new=$(awk -v v="$vol" 'BEGIN{n=v-0.05; if(n<0)n=0; printf "%.4f", n}')
fi
playerctl -p "$player" volume "$new" 2>/dev/null || exit 0
pct=$(awk -v v="$new" 'BEGIN{printf "%d", v*100+0.5}')

# Overlay "timestamp percent" for ~2s, then snap back to the title
# (interval polls are too slow for that, so re-signal explicitly).
now=$(date +%s)
echo "$now $pct" > "$volshow"

# Refresh just this slot right now and again after the overlay expires.
pkill -RTMIN+"$sig" waybar 2>/dev/null || true
( sleep 2.3; pkill -RTMIN+"$sig" waybar 2>/dev/null ) >/dev/null 2>&1 &

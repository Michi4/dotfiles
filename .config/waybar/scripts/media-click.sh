#!/usr/bin/env bash
idx=${1:-0}
cache="/tmp/waybar-media-cache-$idx.txt"
[ -f "$cache" ] && playerctl -p "$(sed -n '1p' "$cache")" play-pause
# Refresh just this slot so play/pause feedback is instant.
pkill -RTMIN+$((8 + idx)) waybar 2>/dev/null || true

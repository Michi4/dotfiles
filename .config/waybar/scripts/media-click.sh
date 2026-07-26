#!/usr/bin/env bash
idx=${1:-0}
cache="/tmp/waybar-media-cache-$idx.txt"
[ -f "$cache" ] && playerctl -p "$(sed -n '1p' "$cache")" play-pause

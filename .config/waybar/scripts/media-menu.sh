#!/usr/bin/env bash
entries=()
players=()
i=0
for player in $(playerctl -l 2>/dev/null); do
  status=$(playerctl -p "$player" status 2>/dev/null)
  [ "$status" = "Stopped" ] && continue
  title=$(playerctl -p "$player" metadata title 2>/dev/null)
  artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
  if [ -n "$artist" ]; then
    label="$artist - $title"
  else
    label="$title"
  fi
  icon="▶"
  [ "$status" = "Paused" ] && icon="⏸"
  entries+=("$icon $label")
  players+=("$player")
done

if [ ${#entries[@]} -eq 0 ]; then
  notify-send "No media players found"
  exit 1
fi

entries+=("⏹ Stop All")
selected=$(printf '%s\n' "${entries[@]}" | wofi --dmenu -p "Media" --lines 10)
[ -z "$selected" ] && exit 0

if [ "$selected" = "⏹ Stop All" ]; then
  playerctl --all-players stop
  notify-send "Stopped all media"
else
  idx=0
  for e in "${entries[@]}"; do
    if [ "$e" = "$selected" ]; then
      playerctl -p "${players[$idx]}" play-pause
      break
    fi
    ((idx++))
  done
fi

#!/usr/bin/env bash
sink=$(pactl info | awk '/Default Sink:/ {print $3}')
while true; do
  vol=$(pactl get-sink-volume "$sink" | awk '{print $5}' | head -n1)
  mute=$(pactl get-sink-mute "$sink" | awk '{print $2}')
  icon=""
  [[ $mute == "yes" ]] && icon=""
  echo "{\"text\":\"$icon $vol\",\"class\":\"volume\"}"
  sleep 1
done


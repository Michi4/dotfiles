#!/bin/bash
FILE=/tmp/gammastep_state
# Default is sunset-auto (Vienna 48.2082,16.3738, 2500K) - was 'off', changed 2026-08-22 per user request
S=$(cat "$FILE" 2>/dev/null || echo sunset)
if [ "$S" = off ]; then
  pkill -x gammastep 2>/dev/null
  systemctl --user restart gammastep 2>/dev/null
  echo sunset > "$FILE"
  notify-send "Sunset — Auto" "Warm 2500K, follows sunrise/sunset (Vienna), fades smoothly" 2>/dev/null
elif [ "$S" = sunset ]; then
  pkill -x gammastep 2>/dev/null
  systemctl --user stop gammastep 2>/dev/null
  sleep 0.2
  gammastep -m wayland -O 1000 2>/dev/null &
  disown
  echo on > "$FILE"
  notify-send "Max — Night" "Forced 1000K extreme red, maximum blue-light block" 2>/dev/null
else
  pkill -x gammastep 2>/dev/null
  systemctl --user stop gammastep 2>/dev/null
  sleep 0.2
  echo off > "$FILE"
  notify-send "Daylight — Off" "Native unfiltered 6500K, no adjustment" 2>/dev/null
fi

#!/bin/bash
ALS="/sys/bus/iio/devices/iio:device0/in_illuminance_raw"
SCALE="/sys/bus/iio/devices/iio:device0/in_illuminance_scale"
BL="/sys/class/backlight/intel_backlight/brightness"
MAX=192000
MIN=5000
STATE=/tmp/auto_brightness_state
LAST=/tmp/auto_brightness_last
[ -f "$STATE" ] || echo on > "$STATE"
if [ "$1" = toggle ]; then
  if [ "$(cat "$STATE" 2>/dev/null || echo on)" = on ]; then
    echo off > "$STATE"
    notify-send "Auto OFF" "Manual" 2>/dev/null
  else
    echo on > "$STATE"
    notify-send "Auto ON" "Follows light" 2>/dev/null
  fi
  exit 0
fi
LAST_T=$(cat "$LAST" 2>/dev/null || cat "$BL" 2>/dev/null || echo $MAX)
while true; do
  [ "$(cat "$STATE" 2>/dev/null || echo on)" = on ] || { sleep 0.5; continue; }
  RAW=$(cat "$ALS" 2>/dev/null || echo 5000); CUR=$(cat "$BL" 2>/dev/null || echo $MAX)
  MEAS_LUX=$(python3 -c "print(int(open('$ALS').read())*0.001)" 2>/dev/null || echo 10)
  DISP_CONTRIB=$(python3 -c "print(int(open('$BL').read())/$MAX*80)" 2>/dev/null || echo 5)
  LUX=$(python3 -c "meas=float('$MEAS_LUX'); disp=float('$DISP_CONTRIB'); print(max(1, meas - disp))" 2>/dev/null || echo 10)
  TARGET=$(python3 -c "import math; l=max(1,min(float('$LUX'),500)); b=int($MIN + ($MAX-$MIN)*(l-5)/495); print(max($MIN,min(b,$MAX)))" 2>/dev/null || echo 50000)
  DIFF=$((CUR - LAST_T)); [ $DIFF -lt 0 ] && DIFF=$(( -DIFF ))
  if [ $DIFF -gt $((MAX/30)) ]; then echo $(date +%s) > /tmp/auto_manual_time; echo $CUR > "$LAST"; LAST_T=$CUR; sleep 0.5; continue; fi
  if [ -f /tmp/auto_manual_time ] && [ $(($(date +%s) - $(cat /tmp/auto_manual_time))) -lt 5 ]; then sleep 0.5; continue; fi
  DIFF2=$((TARGET - CUR)); [ $DIFF2 -lt 0 ] && DIFF2=$(( -DIFF2 ))
  if [ $DIFF2 -gt $((MAX/50)) ]; then
    STEP=$(( (TARGET - CUR) * 30 / 100 )); [ $STEP -eq 0 ] && STEP=$((TARGET > CUR ? 1 : -1)); NEW=$((CUR + STEP))
    echo $NEW | sudo tee "$BL" >/dev/null 2>&1 || brightnessctl set $NEW 2>/dev/null
  fi
  sleep 0.5
done

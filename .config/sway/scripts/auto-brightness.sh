#!/bin/bash
ALS_RAW="/sys/bus/iio/devices/iio:device0/in_illuminance_raw"
ALS_SCALE="/sys/bus/iio/devices/iio:device0/in_illuminance_scale"
BACKLIGHT="/sys/class/backlight/intel_backlight/brightness"
MAX=192000
MIN=1920
STATE_FILE=/tmp/auto_brightness_state
LAST_TARGET_FILE=/tmp/auto_brightness_last_target
LAST_LUX_FILE=/tmp/auto_brightness_last_lux
ENABLED=$(cat "$STATE_FILE" 2>/dev/null || echo on)

if [ "$1" = toggle ]; then
  if [ "$ENABLED" = on ]; then echo off > "$STATE_FILE"; notify-send "🔆 Auto-Brightness OFF" "Manual via brightness keys" 2>/dev/null; else echo on > "$STATE_FILE"; notify-send "🔆 Auto-Brightness ON" "Follows sensor" 2>/dev/null; fi; exit 0
fi

# init last files
LAST_TARGET=$(cat "$LAST_TARGET_FILE" 2>/dev/null || cat "$BACKLIGHT" 2>/dev/null || echo $MAX)
LAST_LUX=$(cat "$LAST_LUX_FILE" 2>/dev/null || echo 10)

while true; do
  ENABLED=$(cat "$STATE_FILE" 2>/dev/null || echo on)
  if [ "$ENABLED" != on ]; then sleep 2; continue; fi
  if [ -f "$ALS_RAW" ]; then
    RAW=$(cat "$ALS_RAW" 2>/dev/null || echo 10000)
    SCALE=$(cat "$ALS_SCALE" 2>/dev/null || echo 0.001)
    LUX=$(python3 -c "print($RAW * $SCALE)" 2>/dev/null || echo 10)
    TARGET=$(python3 -c "
lux=float('$LUX')
lux=max(1,min(lux,2000))
import math
b=int($MIN + ($MAX-$MIN) * math.log(lux+1)/math.log(2001))
print(b)
" 2>/dev/null || echo 20000)
    CURRENT=$(cat "$BACKLIGHT" 2>/dev/null || echo $MAX)
    # Detect manual override: if CURRENT differs from LAST_TARGET by >5% and LUX hasn't changed much (<20%)
    LAST_LUX_VAL=$(cat "$LAST_LUX_FILE" 2>/dev/null || echo $LUX)
    LUX_DIFF=$(python3 -c "a=float('$LUX'); b=float('$LAST_LUX_VAL'); print(abs(a-b)/max(a,b)*100 if max(a,b)>0 else 0)" 2>/dev/null || echo 0)
    TARGET_DIFF=$((TARGET - LAST_TARGET)); if [ $TARGET_DIFF -lt 0 ]; then TARGET_DIFF=$(( -TARGET_DIFF )); fi
    CURRENT_DIFF=$((CURRENT - LAST_TARGET)); if [ $CURRENT_DIFF -lt 0 ]; then CURRENT_DIFF=$(( -CURRENT_DIFF )); fi
    THRESH=$((MAX/20))
    LUX_CHANGE_MAJOR=$(python3 -c "print(1 if float('$LUX_DIFF')>25 else 0)" 2>/dev/null || echo 0)
    MANUAL_OVERRIDE=0
    if [ $CURRENT_DIFF -gt $THRESH ] && [ "$LUX_CHANGE_MAJOR" = "0" ]; then
      # user changed manually, lux stable -> respect manual, update last target to current to avoid fighting
      echo "$CURRENT" > "$LAST_TARGET_FILE"
      echo "$LUX" > "$LAST_LUX_FILE"
      MANUAL_OVERRIDE=1
    fi
    if [ "$MANUAL_OVERRIDE" = "0" ]; then
      # Only set if target differs from current by >5% and (lux changed or first run)
      DIFF=$((TARGET - CURRENT)); if [ $DIFF -lt 0 ]; then DIFF=$(( -DIFF )); fi
      if [ $DIFF -gt $THRESH ]; then
        echo $TARGET | sudo tee "$BACKLIGHT" >/dev/null 2>&1 || brightnessctl set $TARGET 2>/dev/null
        echo "$TARGET" > "$LAST_TARGET_FILE"
      fi
      echo "$LUX" > "$LAST_LUX_FILE"
      LAST_TARGET=$TARGET
    fi
  fi
  sleep 2
done

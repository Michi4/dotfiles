#!/bin/bash
LAST=/tmp/volume_last
NOW=$(date +%s%3N)
LAST_T=$(cat "$LAST" 2>/dev/null || echo 0)
DIFF=$((NOW - LAST_T))
if [ $DIFF -lt 500 ]; then SLEEP=0.05; else SLEEP=0.1; fi
echo $NOW > "$LAST"
pactl set-sink-volume @DEFAULT_SINK@ +1%
for i in 2 3 4 5; do sleep $SLEEP; pactl set-sink-volume @DEFAULT_SINK@ +1%; done

#!/usr/bin/env bash

# Threshold configuration
TEMP_THRESHOLD=30
INTERVAL=120

# Sway Border Colors
NORMAL_FOCUSED="#4c7899 #285577 #ffffff #2e9ef4 #285577"
NORMAL_UNFOCUSED="#333333 #5f676a #ffffff #484e50 #5f676a"
CRITICAL_COLORS="#FF0000 #900000 #FFFFFF #FF0000 #FF0000"

STATE_CRITICAL=false

while true; do
    # Using absolute paths for binaries to prevent daemon startup failures
    MAX_TEMP=$(/usr/bin/sensors | /usr/bin/grep '°C' | /usr/bin/awk '{print $2}' | /usr/bin/grep -oP '\+?\K[0-9]+' | /usr/bin/sort -nr | /usr/bin/head -n 1)

    : "${MAX_TEMP:=0}"

    if [ "$MAX_TEMP" -ge "$TEMP_THRESHOLD" ]; then
        if [ "$STATE_CRITICAL" = false ]; then
            /usr/bin/notify-send -u critical -i thermal-profile-intense \
                "Critical Thermal Warning" \
                "High temperature detected: ${MAX_TEMP}°C across system sensors!"
            STATE_CRITICAL=true
        fi
        
        /usr/bin/swaymsg "client.focused ${CRITICAL_COLORS}; client.unfocused ${CRITICAL_COLORS}"
    else
        if [ "$STATE_CRITICAL" = true ]; then
            /usr/bin/swaymsg "client.focused ${NORMAL_FOCUSED}; client.unfocused ${NORMAL_UNFOCUSED}"
            STATE_CRITICAL=false
        fi
    fi

    /usr/bin/sleep "$INTERVAL"
done

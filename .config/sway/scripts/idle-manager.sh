#!/bin/bash
# Adaptive swayidle: 1min lock on battery, 5min lock on AC
# Keeps Mod+Shift+T toggle working (stay-awake)

STATE_FILE=/tmp/sway_awake_state
LOCK="swaylock -f -c 000000"
AC_ONLINE_FILE="/sys/class/power_supply/AC/online"

get_ac_status() {
  if [ -f "$AC_ONLINE_FILE" ]; then
    cat "$AC_ONLINE_FILE"
  else
    # fallback via upower
    upower -i /org/freedesktop/UPower/devices/line_power_AC 2>/dev/null | grep -q "online.*yes" && echo 1 || echo 0
  fi
}

start_swayidle() {
  pkill swayidle 2>/dev/null
  sleep 0.3
  if [ -f "$STATE_FILE" ]; then
    notify-send "Stay Awake Enabled" "Device will stay awake indefinitely." 2>/dev/null
    return
  fi
  AC=$(get_ac_status)
  # Also switch power profile
  if [ "$AC" = "1" ]; then
    powerprofilesctl set balanced 2>/dev/null || true
    # AC: 5 min lock, 10 min suspend, screen off after 5min + 10s
    timeout_lock=300
    timeout_screen=310
    timeout_suspend=600
    notify_msg="On AC: 5min lock"
  else
    powerprofilesctl set power-saver 2>/dev/null; echo 400000 | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq >/dev/null 2>&1 || true 2>/dev/null || true
    # Battery: 1 min lock, screen off 70s, suspend 180s
    timeout_lock=60
    timeout_screen=70
    timeout_suspend=600
    notify_msg="On Battery: 1min lock"
  fi
  # Run swayidle with appropriate timeouts
  swayidle -w \
    timeout $timeout_lock "$LOCK" \
    timeout $timeout_screen 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
    timeout $timeout_suspend 'systemctl suspend' \
    before-sleep "$LOCK" &
  echo "Started swayidle AC=$AC lock=${timeout_lock}s screen=${timeout_screen}s suspend=${timeout_suspend}s"
}

# initial start
start_swayidle

# monitor AC changes via polling + UPower dbus
# Poll every 10s and also watch UPower
while true; do
  # wait for AC change using inotify or polling
  # Use dbus-monitor for UPower if available, else poll
  # Simple poll loop with 5s interval, but also restart on toggle file change handling via Mod+Shift+T
  sleep 5
  # If awake file changed externally, restart
  # Check if swayidle still running, if not and not in awake mode, restart
  if [ -f "$STATE_FILE" ]; then
    if pgrep -x swayidle >/dev/null; then
      pkill swayidle
    fi
    continue
  fi
  # Detect AC change: compare current desired timeout vs running swayidle args
  # Simplistic: re-evaluate every 30s
  # Check if current AC status would require different timeout than last
  # We'll just restart every 30s if AC mismatched
  # Store last AC
  CUR_AC=$(get_ac_status)
  # Use a cache file
  CACHE="/tmp/sway_idle_last_ac"
  LAST_AC=$(cat "$CACHE" 2>/dev/null || echo "x")
  if [ "$CUR_AC" != "$LAST_AC" ]; then
    echo "$CUR_AC" > "$CACHE"
    start_swayidle
  else
    # also if swayidle died unexpectedly, restart
    if ! pgrep -x swayidle >/dev/null; then
      start_swayidle
    fi
  fi
done

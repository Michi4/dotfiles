#!/usr/bin/env bash
# Show mako notification history in a transient terminal (waybar bell on-click).
# Any key closes; 'd' also dismisses everything + refreshes the bar.
if [ ! -t 0 ]; then
  exec foot -e "$0"
fi
makoctl history 2>/dev/null | head -80
echo "------------------------------------------------"
read -rp "[d]ismiss all, any other key closes: " c < /dev/tty
if [ "$c" = "d" ] || [ "$c" = "D" ]; then
  makoctl dismiss --all 2>/dev/null
  pkill -RTMIN+14 waybar 2>/dev/null || true
fi

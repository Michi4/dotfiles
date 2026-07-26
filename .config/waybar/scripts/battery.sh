#!/usr/bin/env bash
BAT="/org/freedesktop/UPower/devices/battery_BAT0"

upower -m | while true; do
  state=$(upower -i "$BAT" | awk '/state:/ {print $2}')
  perc=$(upower -i "$BAT" | awk '/percentage:/ {gsub("%",""); print int($2)}')
  energy_rate=$(upower -i "$BAT" | awk '/energy-rate:/ {printf "%.1f",$2}')

  # Determine class
  class=$state
  [[ $state == "discharging" ]] && { [[ $perc -le 15 ]] && class="discharging critical"; [[ $perc -le 35 ]] && class="discharging warning"; }

  # JSON output
  echo "{\"text\":\"$perc% (${energy_rate}W)\", \"class\":\"$class\", \"percentage\":$perc, \"progress\":\"<div style='width:${perc}%;'></div>\"}"
  sleep 5
done


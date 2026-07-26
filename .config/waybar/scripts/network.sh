#!/usr/bin/env bash
REAL_IFACES_REGEX='^((en|wl|ww)[opsxa]|eth[0-9])'

get_wifi_info() {
  local iface="$1"
  local link_info
  link_info=$(iw dev "$iface" link 2>/dev/null)
  if [[ -n "$link_info" && "$link_info" == *"Connected"* ]]; then
    ssid=$(echo "$link_info" | grep -oP 'SSID: \K.*')
    signal=$(echo "$link_info" | grep -oP 'signal: -\K\d+')
    echo "$ssid|$signal"
    return 0
  fi
  # fallback to nmcli
  local nm_line
  nm_line=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes:')
  if [[ -n "$nm_line" ]]; then
    ssid=$(echo "$nm_line" | cut -d: -f2)
    signal=$(echo "$nm_line" | cut -d: -f3)
    echo "$ssid|$signal"
    return 0
  fi
  return 1
}

while true; do
  text=""
  tooltip=""
  class="disconnected"

  # Find the real WiFi/Ethernet interface
  iface=""
  for i in /sys/class/net/*; do
    name=$(basename "$i")
    [[ "$name" == "lo" ]] && continue
    [[ "$name" =~ $REAL_IFACES_REGEX ]] && iface="$name" && break
  done

  if [[ -n "$iface" ]]; then
    state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
    if [[ "$state" == "up" ]]; then
      class="connected"
      wifi_info=$(get_wifi_info "$iface")
      if [[ -n "$wifi_info" ]]; then
        ssid="${wifi_info%|*}"
        signal="${wifi_info#*|}"
        maxssid=18
        if [ "${#ssid}" -gt "$maxssid" ]; then
          ssid="${ssid:0:$((maxssid - 1))}…"
        fi
        text=" $ssid ${signal}%"
      else
        ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}')
        text="󰈀 $ip"
      fi
    fi
  fi

  [[ -z "$text" ]] && text="󰤮 Disconnected"

  # Tooltip: all interfaces in a table
  tooltip_lines=()
  for i in /sys/class/net/*; do
    name=$(basename "$i")
    [[ "$name" == "lo" ]] && continue
    state=$(cat "$i/operstate" 2>/dev/null)
    [[ "$state" == "unknown" ]] && state="virtual"
    ips=$(ip -4 addr show "$name" 2>/dev/null | awk '/inet / {print $2}' | paste -sd,)
    [[ -z "$ips" ]] && ips="—"
    tooltip_lines+=("$(printf '%-10s%-16s%s' "$state" "$name" "$ips")")
  done
  tooltip=""
  for line in "${tooltip_lines[@]}"; do
    [[ -n "$tooltip" ]] && tooltip+="\\n"
    tooltip+="$line"
  done

  # Escape for Pango
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  tooltip="${tooltip//&/&amp;}"
  tooltip="${tooltip//</&lt;}"
  tooltip="${tooltip//>/&gt;}"

  echo "{\"text\":\"$text\",\"tooltip\":\"$tooltip\",\"class\":\"$class\"}"
  sleep 5
done

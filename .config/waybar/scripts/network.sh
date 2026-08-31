#!/usr/bin/env bash
# Force a UTF-8 locale so multi-byte SSIDs are handled correctly.
for l in en_US.utf8 C.utf8 en_US.UTF-8 C.UTF-8; do
  if locale -a 2>/dev/null | grep -iqx "$l"; then
    export LANG="$l"; export LC_ALL="$l"; break
  fi
done

REAL_IFACES_REGEX='^((en|wl|ww)[opsxa]|eth[0-9])'

# iw prints non-ASCII SSID bytes as \xHH escapes; turn them back into real UTF-8.
unescape() {
  printf '%s' "$1" | perl -pe 's/\\x([0-9a-fA-F]{2})/chr(hex($1))/ge' 2>/dev/null || printf '%s' "$1"
}

get_wifi_info() {
  local iface="$1" link_info nm_line ssid signal
  link_info=$(iw dev "$iface" link 2>/dev/null)
  if [[ -n "$link_info" && "$link_info" == *"Connected"* ]]; then
    ssid=$(unescape "$(printf '%s' "$link_info" | grep -oP 'SSID: \K.*')")
    signal=$(printf '%s' "$link_info" | grep -oP 'signal: -\K\d+')
    echo "$ssid|$signal"
    return 0
  fi
  nm_line=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes:')
  if [[ -n "$nm_line" ]]; then
    ssid=$(printf '%s' "$nm_line" | cut -d: -f2)
    signal=$(printf '%s' "$nm_line" | cut -d: -f3)
    echo "$ssid|$signal"
    return 0
  fi
  return 1
}

# Pick the interface to display:
#   1) an UP wifi interface (preferred)
#   2) any other UP real interface
#   3) any real interface that actually has an IPv4 address
#   4) whatever NetworkManager reports as connected
pick_interface() {
  local n st best=""
  for i in /sys/class/net/*; do
    n=$(basename "$i"); [[ "$n" == "lo" ]] && continue
    [[ "$n" =~ $REAL_IFACES_REGEX ]] || continue
    st=$(cat "$i/operstate" 2>/dev/null)
    if [[ "$st" == "up" ]]; then
      if [[ "$n" == wl* ]]; then echo "$n"; return 0; fi
      [[ -z "$best" ]] && best="$n"
    fi
  done
  [[ -n "$best" ]] && { echo "$best"; return 0; }
  for i in /sys/class/net/*; do
    n=$(basename "$i"); [[ "$n" == "lo" ]] && continue
    [[ "$n" =~ $REAL_IFACES_REGEX ]] || continue
    if ip -4 addr show "$n" 2>/dev/null | grep -q 'inet '; then echo "$n"; return 0; fi
  done
  nmcli -t -f DEVICE,STATE dev status 2>/dev/null | awk -F: '$2=="connected"{print $1; exit}'
}

while true; do
  text=""; tooltip=""; class="disconnected"

  iface=$(pick_interface)
  if [[ -n "$iface" ]]; then
    class="connected"
    wifi_data=$(get_wifi_info "$iface")
    ssid="${wifi_data%|*}"
    signal="${wifi_data#*|}"
    if [[ -n "$ssid" ]]; then
      maxssid=18
      if (( ${#ssid} > maxssid )); then
        ssid="${ssid:0:$((maxssid - 1))}…"
      fi
      text=" $ssid ${signal}%"
    else
      ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}')
      text="󰈀 ${ip:-$iface}"
    fi
  fi

  [[ -z "$text" ]] && text="󰤮 Disconnected"

  # Tooltip: every interface
  tooltip_lines=()
  for i in /sys/class/net/*; do
    n=$(basename "$i"); [[ "$n" == "lo" ]] && continue
    st=$(cat "$i/operstate" 2>/dev/null); [[ "$st" == "unknown" ]] && st="virtual"
    ips=$(ip -4 addr show "$n" 2>/dev/null | awk '/inet / {print $2}' | paste -sd,)
    [[ -z "$ips" ]] && ips="—"
    tooltip_lines+=("$(printf '%-10s%-16s%s' "$st" "$n" "$ips")")
  done
  tooltip=""
  for line in "${tooltip_lines[@]}"; do
    [[ -n "$tooltip" ]] && tooltip+="\\n"
    tooltip+="$line"
  done

  text="${text//&/&amp;}";   text="${text//</&lt;}";   text="${text//>/&gt;}"
  tooltip="${tooltip//&/&amp;}"; tooltip="${tooltip//</&lt>}"; tooltip="${tooltip//>/&gt;}"

  echo "{\"text\":\"$text\",\"tooltip\":\"$tooltip\",\"class\":\"$class\"}"
  sleep 5
done

#!/usr/bin/env bash
while true; do
  usb_count=$(lsblk -d -o TRAN | grep -i -c "usb" || true)
  if [ "$usb_count" -eq 0 ]; then
    text=" 0"
    tooltip="No USB storage connected"
    class="none"
  else
    text=" $usb_count"
    tooltip=$(lsblk -d -o MODEL,SIZE,TRAN | awk 'tolower($3)=="usb" {print $1, $2}' | paste -sd "\n")
    class="active"
  fi
  
  jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" '{"text": $text, "tooltip": $tooltip, "class": $class}'
  
  sleep 5
done


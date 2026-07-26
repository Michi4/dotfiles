#!/usr/bin/env bash
while true; do
  cal=$(cal -m)
  nl=$'\n'
  tooltip="$(date '+%a %d %b %H:%M:%S')${nl}${nl}${cal}"
  echo "{\"text\":\"$(date '+%a %d %b %H:%M')\",\"tooltip\":\"${tooltip}\",\"class\":\"datetime\"}"
  sleep 1
done

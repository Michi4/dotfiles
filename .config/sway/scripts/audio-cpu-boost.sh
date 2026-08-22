#!/bin/bash
while true; do
  REAL=$(pw-dump 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    cnt=sum(1 for n in d if n.get('type')=='PipeWire:Interface:Node' and n.get('info',{}).get('props',{}).get('media.class')=='Stream/Output/Audio' and n.get('info',{}).get('props',{}).get('application.name')!='pw-cat' and n.get('info',{}).get('state')=='running')
    print(cnt)
except: print(0)
" 2>/dev/null || echo 0)
  if [ "$REAL" -gt 0 ]; then
    sudo -n /usr/local/bin/cpu-max 2000000 2>/dev/null
  else
    AC=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)
    if [ "$AC" = "0" ]; then
      sudo -n /usr/local/bin/cpu-max 400000 2>/dev/null
    else
      sudo -n /usr/local/bin/cpu-max 3500000 2>/dev/null
    fi
  fi
  sleep 2
done

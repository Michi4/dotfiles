#!/usr/bin/env bash
idx=${1:-0}
cache="/tmp/waybar-media-cache-$idx.txt"
state="/tmp/waybar-media-state"
lock="/tmp/waybar-media.lock"
# ---- Dynamic media width budget (derived from screen size) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CSS_FILE="$ROOT_DIR/style.css"
BUDGET_CACHE="/tmp/waybar-media-budget.txt"

get_font_size() {
  local fs
  fs=$(grep -m1 -oE 'font-size:[[:space:]]*[0-9]+px' "$CSS_FILE" 2>/dev/null | grep -oE '[0-9]+')
  echo "${fs:-15}"
}

# Smallest currently-active output width in logical pixels.
get_smallest_width() {
  local w
  if command -v swaymsg >/dev/null 2>&1; then
    w=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.active==true) | .rect.width' 2>/dev/null | sort -n | head -1)
  fi
  if [ -z "$w" ] && command -v wlr-randr >/dev/null 2>&1; then
    w=$(wlr-randr 2>/dev/null | grep -oiE 'current:?[[:space:]]*[0-9]+x[0-9]+' | sed -E 's/.*([0-9]+)x[0-9]+/\1/' | sort -n | head -1)
  fi
  if [ -z "$w" ] && command -v xrandr >/dev/null 2>&1; then
    w=$(xrandr --current 2>/dev/null | grep -w connected | grep -oE '[0-9]+x[0-9]+\+' | cut -d'x' -f1 | sort -n | head -1)
  fi
  echo "$w"
}

# Width of the tray, derived from the real number of status-notifier icons
# (each icon ~ one char + the configured 10px spacing, plus 30px module padding).
get_tray_px() {
  local char_px=$1 count=0 out
  for svc in org.kde.StatusNotifierWatcher org.freedesktop.StatusNotifierWatcher; do
    out=$(gdbus call --session --dest "$svc" --object-path /StatusNotifierWatcher \
      --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher \
      RegisteredStatusNotifierItems 2>/dev/null)
    if [ -n "$out" ]; then
      count=$(printf '%s' "$out" | grep -oE "'[^']*'" | wc -l)
      break
    fi
  done
  echo $(( 30 + count * (char_px + 12) ))
}

# Pixel width reserved for everything EXCEPT the media slots: workspaces (left)
# plus the whole right-side cluster (tray, network, volume, cpu, ram, battery,
# weather, clock). The remaining space is what media is allowed to use.
get_reserve_px() {
  local char_px=$1 right nw ww ws wscount
  # clock text is deterministic -> compute directly (avoids spawning the loop)
  local cw
  cw=$(date '+%a %d %b %H:%M'); cw=${#cw}
  # network + weather: measure live, in parallel
  ( timeout 1 bash "$SCRIPT_DIR/network.sh" 2>/dev/null | head -1 \
      | sed -E 's/.*"text"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' > /tmp/.m_net ) &
  ( timeout 1 bash "$SCRIPT_DIR/weather.sh" 2>/dev/null | head -1 \
      | sed -E 's/.*"text"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' > /tmp/.m_wea ) &
  wait
  nw=$(cat /tmp/.m_net 2>/dev/null); nw=${#nw}; [ "$nw" -lt 12 ] && nw=12
  ww=$(cat /tmp/.m_wea 2>/dev/null); ww=${#ww}; [ "$ww" -lt 6 ] && ww=6
  right=$(( (cw + nw + ww) * char_px + 3 * 20 ))
  # built-in right-side modules: longest possible text per format so they
  # always show in full (pulseaudio " 100%", cpu "CPU 100%", memory "15.9G", battery "100% 25.0W")
  for c in 6 8 5 10; do  # pulseaudio, cpu, memory, battery
    right=$(( right + c * char_px + 20 ))
  done
  # tray: measured from the real icon count
  right=$(( right + $(get_tray_px "$char_px") ))
  # workspaces sit on the left, before the media slots
  wscount=$(swaymsg -t get_workspaces 2>/dev/null | jq 'length' 2>/dev/null)
  [ -z "$wscount" ] && wscount=9
  ws=$(( wscount * (char_px + 16) + 10 ))
  echo $(( right + ws ))
}

# Budget is recomputed at most every few seconds and shared by all slots.
get_media_budget() {
  local width char_px reserve spare budget now cached_ts cached_val
  now=$(date +%s)
  if [ -f "$BUDGET_CACHE" ]; then
    read -r cached_ts cached_val < "$BUDGET_CACHE" 2>/dev/null
    if [ -n "$cached_val" ] && [ $((now - ${cached_ts:-0})) -lt 5 ]; then
      echo "$cached_val"; return
    fi
  fi
  width=$(get_smallest_width)
  [ -z "$width" ] && width=1920
  char_px=$(awk "BEGIN{printf \"%d\", ($(get_font_size) * 0.6) + 0.5}")
  [ "$char_px" -lt 1 ] && char_px=1
  # Reserve the real width of all other modules, then give media the rest.
  # (integer division floors, leaving a sub-character buffer for the clock)
  reserve=$(get_reserve_px "$char_px")
  spare=$(( width - reserve ))
  budget=$(( spare / char_px ))
  [ "$budget" -lt 12 ] && budget=12
  [ "$budget" -gt 130 ] && budget=130
  echo "$now $budget" > "$BUDGET_CACHE"
  echo "$budget"
}

BUDGET=$(get_media_budget)

escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  echo -n "$s"
}

# Read our cache
cached_player=""
if [ -f "$cache" ]; then
  cached_player=$(sed -n '1p' "$cache")
fi

# Build list of active players, filtering duplicate sources
has_mprisence=false
player_list=$(playerctl -l 2>/dev/null)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [[ "$p" == mprisence_web.* ]] && has_mprisence=true
done <<< "$player_list"

active=()
playing=()
while IFS= read -r p; do
  [ -z "$p" ] && continue
  $has_mprisence && [[ "$p" == firefox.instance* ]] && continue
  s=$(playerctl -p "$p" status 2>/dev/null)
  [ "$s" != "Stopped" ] 2>/dev/null && active+=("$p")
  [ "$s" = "Playing" ] 2>/dev/null && playing+=("$p")
done <<< "$player_list"
count=${#active[@]}

# Coordinate assignment via lock + shared state
exec 9>"$lock"
flock -x 9

# Read current assignments: slot -> "player|full_len"
declare -A assigned
if [ -f "$state" ]; then
  while IFS='=' read -r sid rest; do
    [ -n "$sid" ] && assigned["$sid"]="$rest"
  done < "$state"
fi

# Build set of players claimed by OTHER slots
declare -A claimed
for sid in "${!assigned[@]}"; do
  if [ "$sid" != "$idx" ]; then
    sp="${assigned[$sid]%%|*}"
    [ -n "$sp" ] && claimed["$sp"]=1
  fi
done

# Determine player:
# - stick with cached if still active AND not stolen by another slot (keep showing even if paused)
# - otherwise fall back to first unclaimed PLAYING player (don't show tabs that are merely open/paused)
player=""
if [ -n "$cached_player" ]; then
  for p in "${active[@]}"; do
    if [ "$p" = "$cached_player" ] && [ -z "${claimed[$p]}" ]; then
      player="$p"
      break
    fi
  done
fi

if [ -z "$player" ]; then
  for p in "${playing[@]}"; do
    if [ -z "${claimed[$p]}" ]; then
      player="$p"
      break
    fi
  done
fi

# Compute this slot's full (untruncated) text length
full_len=0
full_text=""
if [ -n "$player" ]; then
  metadata=$(playerctl -p "$player" metadata --format '{{status}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null) || metadata=""
  IFS='|' read -r status artist title album <<< "$metadata"
  if [ -n "$status" ] && [ "$status" != "Stopped" ] 2>/dev/null && [ -n "$title" ]; then
    title=$(escape "$title")
    artist=$(escape "$artist")
    album=$(escape "$album")
    if [ -n "$artist" ]; then
      full_text="♫ $artist - $title"
    else
      full_text="♫ $title"
    fi
    full_len=${#full_text}
  fi
fi

# Update state with this slot's player + full_len
assigned["$idx"]="$player|$full_len"

# Gather all slots' full_len in order 0..5
lengths=()
for i in 0 1 2 3 4 5; do
  rest="${assigned[$i]}"
  fl="${rest##*|}"
  [ -z "$fl" ] && fl=0
  lengths+=("$fl")
done

# Water-fill allocation to fit BUDGET across all active slots
lo=0
hi=0
for L in "${lengths[@]}"; do [ "$L" -gt "$hi" ] && hi=$L; done
while [ "$lo" -lt "$hi" ]; do
  mid=$(( (lo + hi + 1) / 2 ))
  total=0
  for L in "${lengths[@]}"; do
    if [ "$L" -lt "$mid" ]; then total=$((total + L)); else total=$((total + mid)); fi
  done
  if [ "$total" -le "$BUDGET" ]; then lo=$mid; else hi=$((mid - 1)); fi
done
threshold=$lo

# This slot's display length
disp_len=${lengths[$idx]}
if [ "$disp_len" -gt "$threshold" ]; then disp_len=$threshold; fi

# Write state atomically
: > "$state"
for sid in "${!assigned[@]}"; do
  echo "${sid}=${assigned[$sid]}" >> "$state"
done

exec 9>&-

# Build display text + tooltip
# Show if Playing, or if Paused but we were already showing it (sticky).
if [ -n "$player" ] && [ -n "$full_text" ]; then
  if [ "$status" = "Playing" ] || [ "$player" = "$cached_player" ]; then
    text="$full_text"
    if [ "$disp_len" -lt "${#text}" ]; then
      text="${text:0:$((disp_len - 3))}..."
    fi
    tooltip="$text"
    [ -n "$album" ] && tooltip="$tooltip · $album"
    printf '%s\n' "$player" "$text" "$tooltip" > "$cache"
    echo "{\"text\":\"$text\",\"tooltip\":\"$tooltip\",\"class\":\"$status\"}"
    exit 0
  fi
fi

rm -f "$cache"
echo '{"text":"","class":"stopped"}'

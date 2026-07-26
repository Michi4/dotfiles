#!/usr/bin/env bash
STATE_DIR="/tmp/waybar-media"
PIDFILE="/tmp/waybar-media-daemon.pid"

mkdir -p "$STATE_DIR"

pidfile="/tmp/waybar-media-daemon.pid"
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$pidfile"

escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  echo -n "$s"
}

declare -A last_text
declare -A last_tooltip

while true; do
  player_list=$(playerctl -l 2>/dev/null)
  order=()

  for player in $player_list; do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [ "$status" = "Stopped" ] 2>/dev/null; then
      continue
    fi
    order+=("$player")
    if [ "$status" = "Playing" ] || [ -z "${last_text[$player]}" ]; then
      title=$(escape "$(playerctl -p "$player" metadata title 2>/dev/null)")
      artist=$(escape "$(playerctl -p "$player" metadata artist 2>/dev/null)")
      album=$(escape "$(playerctl -p "$player" metadata album 2>/dev/null)")
      if [ -n "$artist" ]; then
        last_text["$player"]="♫ $artist - $title"
      else
        last_text["$player"]="♫ $title"
      fi
      last_tooltip["$player"]="${last_text[$player]}"
      [ -n "$album" ] && last_tooltip["$player"]="${last_tooltip[$player]} · $album"
    fi
  done

  for player in "${!last_text[@]}"; do
    if ! echo "$player_list" | grep -qx "$player"; then
      unset last_text["$player"]
      unset last_tooltip["$player"]
    fi
  done

  rm -f "$STATE_DIR"/*.json "$STATE_DIR/order"
  idx=0
  for player in "${order[@]}"; do
    if [ -n "${last_text[$player]}" ]; then
      status=$(playerctl -p "$player" status 2>/dev/null)
      text="${last_text[$player]}"
      tooltip="${last_tooltip[$player]}"
      cat > "$STATE_DIR/$idx.json" <<-EOF
{"text":"$text","tooltip":"$tooltip","class":"$status"}
EOF
      printf '%s\n' "$player" > "$STATE_DIR/$idx.player"
    fi
    ((idx++))
  done

  sleep 1
done

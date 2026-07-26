#!/usr/bin/env bash
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
  active=()
  for player in $(playerctl -l 2>/dev/null); do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [ "$status" = "Stopped" ] 2>/dev/null; then
      continue
    fi
    active+=("$player")
    if [ "$status" = "Playing" ] || [ -z "${last_text[$player]}" ]; then
      title=$(escape "$(playerctl -p "$player" metadata title 2>/dev/null)")
      artist=$(escape "$(playerctl -p "$player" metadata artist 2>/dev/null)")
      album=$(escape "$(playerctl -p "$player" metadata album 2>/dev/null)")
      name=$(escape "$(playerctl -p "$player" metadata xesam:url 2>/dev/null | sed 's|https\?://||;s|www\.||;s|/.*||' || echo "$player")")
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
    if ! playerctl -l 2>/dev/null | grep -qx "$player"; then
      unset last_text["$player"]
      unset last_tooltip["$player"]
    fi
  done

  if [ ${#active[@]} -gt 0 ]; then
    text=""
    tooltip=""
    first=true
    for player in "${active[@]}"; do
      t="${last_text[$player]}"
      tt="${last_tooltip[$player]}"
      if $first; then
        text="$t"
        tooltip="$tt"
        first=false
      else
        text="$text  $t"
        tooltip="$tooltip\n$tt"
      fi
    done
    echo "{\"text\":\"$text\",\"tooltip\":\"$tooltip\",\"class\":\"playing\"}"
  else
    echo '{"text":"","class":"stopped"}'
  fi
  sleep 1
done

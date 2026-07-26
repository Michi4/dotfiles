#!/usr/bin/env bash
# Location: Linz, Austria (change LAT/LON for your spot)
LAT="48.3069"
LON="14.2858"

get_icon() {
  case "$1" in
    0) echo "☀";;       # clear
    1|2|3) echo "⛅";;  # partly cloudy
    45|48) echo "🌫";;  # fog
    51|53|55) echo "🌦";; # drizzle
    56|57) echo "🌧";;  # freezing drizzle
    61|63|65) echo "🌧";; # rain
    66|67) echo "🌧";;  # freezing rain
    71|73|75|77) echo "❄";; # snow
    80|81|82) echo "🌦";; # rain showers
    85|86) echo "❄";;  # snow showers
    95|96|99) echo "⛈";; # thunderstorm
    *) echo "🌡";;
  esac
}

while true; do
  data=$(curl -sf "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=4")
  if [ -n "$data" ]; then
    temp=$(echo "$data" | jq -r '.current.temperature_2m')
    code=$(echo "$data" | jq -r '.current.weather_code')
    icon=$(get_icon "$code")

    tooltip="Linz, Austria\n$icon $temp°C\n"
    for i in 0 1 2 3; do
      date=$(echo "$data" | jq -r ".daily.time[$i]")
      max=$(echo "$data" | jq -r ".daily.temperature_2m_max[$i]")
      min=$(echo "$data" | jq -r ".daily.temperature_2m_min[$i]")
      fcode=$(echo "$data" | jq -r ".daily.weather_code[$i]")
      ficon=$(get_icon "$fcode")
      tooltip="$tooltip\n$date  $ficon $min-$max°C"
    done

    echo "{\"text\":\"$icon $temp°\",\"tooltip\":\"$tooltip\",\"class\":\"weather\"}"
  else
    echo '{"text":"","class":"weather"}'
  fi
  sleep 600
done

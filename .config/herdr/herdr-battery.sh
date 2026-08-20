#!/usr/bin/env bash
# Battery indicator for the herdr tab bar (ui.tab_bar_right).
# Prints e.g. "󰂀 64%", "󰂄 64%" while charging; prints nothing when there is no battery.
set -uo pipefail

read -r pct state < <(
  pmset -g batt | awk '
    /InternalBattery/ {
      gsub(/[;%]/, "", $3)
      gsub(/;/, "", $4)
      if ($0 ~ /not charging/) $4 = "plugged"
      print $3, $4
      exit
    }'
)

[ -n "${pct:-}" ] || exit 0

case "${state:-}" in
  charging|finishing) icon="󰂄" ;;
  charged|plugged)    icon="󰚥" ;;
  *)
    if   [ "$pct" -ge 90 ]; then icon="󰁹"
    elif [ "$pct" -ge 70 ]; then icon="󰂂"
    elif [ "$pct" -ge 50 ]; then icon="󰂀"
    elif [ "$pct" -ge 30 ]; then icon="󰁽"
    elif [ "$pct" -ge 15 ]; then icon="󰁻"
    else                         icon="󰂃"
    fi
    ;;
esac

printf '%s %s%%' "$icon" "$pct"

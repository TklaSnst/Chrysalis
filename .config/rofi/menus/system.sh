#!/usr/bin/env bash
# betterdeb control plane — system actions

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"

CHOICE=$(printf \
    "  Lock\n\
  Suspend\n\
  Logout\n\
  Reboot\n\
  Shutdown" \
    | rofi -dmenu \
           -p "System" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 320px; } listview { lines: 5; }')

case "$CHOICE" in
    *Lock*)     loginctl lock-session ;;
    *Suspend*)  systemctl suspend ;;
    *Logout*)
        if command -v hyprctl &>/dev/null; then
            hyprctl dispatch exit
        elif command -v swaymsg &>/dev/null; then
            swaymsg exit
        fi
        ;;
    *Reboot*)   systemctl reboot ;;
    *Shutdown*) systemctl poweroff ;;
esac

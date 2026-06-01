#!/usr/bin/env bash
# betterdeb control plane — keyboard layout switcher

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"

CHOICE=$(printf "  English (US)\n  Русский" \
    | rofi -dmenu \
           -p "Language" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 320px; } listview { lines: 2; }')

case "$CHOICE" in
    *English*)
        if command -v hyprctl &>/dev/null; then
            hyprctl switchxkblayout all 0
        elif command -v swaymsg &>/dev/null; then
            swaymsg "input type:keyboard xkb_switch_layout 0"
        fi
        ;;
    *Русский*)
        if command -v hyprctl &>/dev/null; then
            hyprctl switchxkblayout all 1
        elif command -v swaymsg &>/dev/null; then
            swaymsg "input type:keyboard xkb_switch_layout 1"
        fi
        ;;
esac

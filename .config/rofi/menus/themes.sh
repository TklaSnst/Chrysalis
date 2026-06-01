#!/usr/bin/env bash
# betterdeb control plane — theme switcher

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"
SWITCH="${XDG_CONFIG_HOME:-$HOME/.config}/themes/switch.sh"

CHOICE=$(printf \
    "  Catppuccin Mocha\n\
  Nord\n\
  Everforest Dark\n\
  Gruvbox Dark\n\
  Tokyo Night\n\
  Kanagawa" \
    | rofi -dmenu \
           -p "Theme" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 380px; } listview { lines: 6; }')

case "$CHOICE" in
    *Catppuccin*) bash "$SWITCH" catppuccin ;;
    *Nord*)       bash "$SWITCH" nord ;;
    *Everforest*) bash "$SWITCH" everforest ;;
    *Gruvbox*)    bash "$SWITCH" gruvbox ;;
    *Tokyo*)      bash "$SWITCH" tokyonight ;;
    *Kanagawa*)   bash "$SWITCH" kanagawa ;;
esac

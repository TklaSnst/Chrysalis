#!/usr/bin/env bash
# betterdeb control plane — main menu (Super+Alt+Space)

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHOICE=$(printf \
    "  Apps\n\
  Themes\n\
  System\n\
  Keybindings\n\
  Language\n\
  Wallpaper" \
    | rofi -dmenu \
           -p "" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 380px; } listview { lines: 6; }')

case "$CHOICE" in
    *Apps*)        rofi -show drun -theme "$ROFI_THEME" ;;
    *Themes*)      exec "$DIR/themes.sh" ;;
    *System*)      exec "$DIR/system.sh" ;;
    *Keybindings*) exec "$DIR/keybindings.sh" ;;
    *Language*)    exec "$DIR/language.sh" ;;
    *Wallpaper*)   exec "$DIR/wallpaper.sh" ;;
esac

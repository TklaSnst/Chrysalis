#!/usr/bin/env bash
# betterdeb control plane — wallpaper picker

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"
WALL_DIR="${HOME}/Pictures/Wallpapers"

if [[ ! -d "$WALL_DIR" ]]; then
    rofi -e "Wallpaper directory not found: $WALL_DIR" -theme "$ROFI_THEME"
    exit 1
fi

CHOICE=$(find "$WALL_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) \
    | sed "s|$WALL_DIR/||" \
    | sort \
    | rofi -dmenu \
           -p "Wallpaper" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 500px; } listview { lines: 10; }')

[[ -z "$CHOICE" ]] && exit 0

FULL_PATH="$WALL_DIR/$CHOICE"

# Set wallpaper and update symlink
swaybg -i "$FULL_PATH" -m fill &
ln -sf "$FULL_PATH" "${XDG_CONFIG_HOME:-$HOME/.config}/wallpapers/current"

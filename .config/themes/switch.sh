#!/usr/bin/env bash
# betterdeb theme switcher
# Usage: switch.sh <theme-name>

set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEMES_DIR="$CFG/themes"
AVAILABLE=(catppuccin nord everforest gruvbox tokyonight kanagawa)

usage() {
    echo "Usage: switch.sh <theme>"
    printf "Available: %s\n" "${AVAILABLE[*]}"
    exit 1
}

[[ $# -lt 1 ]] && usage

THEME="$1"
YAML="$THEMES_DIR/${THEME}.yaml"

if [[ ! -f "$YAML" ]]; then
    echo "Error: theme '$THEME' not found at $YAML" >&2
    exit 1
fi

echo "Switching to: $THEME"

ln -sf "$YAML" "$THEMES_DIR/current.yaml"
python3 "$THEMES_DIR/build.py"

# Reload running compositor
if command -v hyprctl &>/dev/null && hyprctl version &>/dev/null 2>&1; then
    hyprctl reload &>/dev/null && echo "  [ok] Hyprland reloaded"
elif command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null 2>&1; then
    swaymsg reload &>/dev/null && echo "  [ok] Sway reloaded"
fi

# Waybar hot reload (SIGUSR2)
if pgrep -x waybar &>/dev/null; then
    pkill -SIGUSR2 waybar && echo "  [ok] Waybar reloaded"
fi

echo "Done."

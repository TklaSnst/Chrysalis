#!/usr/bin/env bash
# betterdeb control plane — keybindings reference

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"
HYPR_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/hyprland/hyprland.conf"

# Try to parse hyprland.conf bind lines; fallback to hardcoded list
if [[ -f "$HYPR_CFG" ]]; then
    BINDS=$(grep -E '^\s*bind' "$HYPR_CFG" \
        | sed 's/bind[el]* = //;s/,/  →  /3;s/,/  /;s/exec, //;s/ {.*}$//' \
        | sort -u \
        | head -60)
else
    BINDS=$(cat <<'EOF'
SUPER + Return          →  Terminal (kitty)
SUPER + Space           →  App launcher (wofi)
SUPER + Alt + Space     →  Control plane (rofi)
SUPER + B               →  Browser (firefox)
SUPER + E               →  Editor (code)
SUPER + F               →  Files (thunar)
SUPER + Shift + Q       →  Kill window
SUPER + Shift + E       →  Exit Hyprland
SUPER + Shift + C       →  Reload Hyprland
SUPER + Shift + W       →  Restart Waybar
SUPER + Shift + F       →  Toggle float
SUPER + M               →  Maximize window
SUPER + Shift + M       →  Fullscreen
SUPER + S               →  Scratchpad toggle
SUPER + R               →  Resize mode
SUPER + K               →  Color picker (hyprpicker)
SUPER + 1–0             →  Switch workspace
SUPER + Shift + 1–0     →  Move window to workspace
Print                   →  Screenshot area → clipboard
Shift + Print           →  Screenshot area → file
Ctrl + Print            →  Screenshot screen → clipboard
XF86AudioPlay           →  Play/pause
XF86AudioNext/Prev      →  Next/previous track
XF86AudioMute           →  Mute
XF86MonBrightness       →  Screen brightness
EOF
)
fi

echo "$BINDS" \
    | rofi -dmenu \
           -p "Keybindings" \
           -theme "$ROFI_THEME" \
           -theme-str 'window { width: 640px; } listview { lines: 12; } entry { placeholder: "Filter..."; }' \
           -no-custom \
           -format d \
    >/dev/null

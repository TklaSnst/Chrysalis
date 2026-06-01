#!/usr/bin/env bash
# cava → waybar bridge: outputs one JSON line per frame for custom module
# Requires: cava

BARS=8
CAVA_CFG="/tmp/cava-waybar-$$.conf"
BLOCKS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

cleanup() { rm -f "$CAVA_CFG"; }
trap cleanup EXIT

if ! command -v cava &>/dev/null; then
    echo '{"text": "no cava", "class": "disabled"}'
    exit 1
fi

cat > "$CAVA_CFG" <<EOF
[general]
bars = $BARS
framerate = 30
sensitivity = 200

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cava -p "$CAVA_CFG" 2>/dev/null | while IFS=';' read -ra VALS; do
    text=""
    for v in "${VALS[@]}"; do
        [[ -z "$v" || "$v" == $'\n' ]] && continue
        i=$(( v > 7 ? 7 : v < 0 ? 0 : v ))
        text+="${BLOCKS[$i]}"
    done
    [[ -n "$text" ]] && printf '{"text":"%s","class":"active"}\n' "$text"
done

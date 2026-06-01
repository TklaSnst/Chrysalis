#!/usr/bin/env bash
# Chrysalis — config backup script
# Creates a timestamped archive of your current config

set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="${HOME}/.local/share/chrysalis/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$BACKUP_DIR/chrysalis_backup_$TIMESTAMP.tar.gz"

TARGETS=(
    "$CFG/hyprland"
    "$CFG/sway"
    "$CFG/waybar"
    "$CFG/kitty"
    "$CFG/themes"
    "$CFG/rofi"
    "$CFG/wofi"
    "$CFG/scripts"
)

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $ARCHIVE"

# Build list of existing targets
EXISTING=()
for t in "${TARGETS[@]}"; do
    [[ -e "$t" ]] && EXISTING+=("$t")
done

tar -czf "$ARCHIVE" "${EXISTING[@]}" 2>/dev/null
echo "Done: $(du -sh "$ARCHIVE" | cut -f1)"

# Keep only 10 most recent backups
BACKUPS=("$BACKUP_DIR"/chrysalis_backup_*.tar.gz)
if (( ${#BACKUPS[@]} > 10 )); then
    printf '%s\n' "${BACKUPS[@]}" | sort | head -n -10 | xargs rm -f
    echo "Old backups pruned (keeping 10 most recent)"
fi

echo "Backup location: $BACKUP_DIR"

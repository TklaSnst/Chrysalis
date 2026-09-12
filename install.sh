#!/usr/bin/env bash
# =============================================================================
# Chrysalis — automated installer
# Hyprland + waybar + wofi + swaync + alacritty with a JSON-driven theme system
# =============================================================================

set -euo pipefail

# ─── Colors & styles ──────────────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; M='\033[1;35m'; C='\033[1;36m'
W='\033[1;37m'; D='\033[0m'

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
FONTS="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

# ─── Helpers ──────────────────────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${M}"
    cat << 'BANNER'
   ____ _                          _ _
  / ___| |__  _ __ _   _ ___  __ _| (_)___
 | |   | '_ \| '__| | | / __|/ _` | | / __|
 | |___| | | | |  | |_| \__ \ (_| | | \__ \
  \____|_| |_|_|   \__, |___/\__,_|_|_|___/
                   |___/
BANNER
    echo -e "${D}  ${C}A clean Debian/Ubuntu Hyprland setup${D}"
    echo -e "  ${W}https://github.com/TklaSnst/Chrysalis${D}\n"
}

step()    { echo -e "\n${B}━━━ ${W}$*${D}"; }
ok()      { echo -e "  ${G}✓${D} $*"; }
warn()    { echo -e "  ${Y}⚠${D}  $*"; }
fail()    { echo -e "  ${R}✗${D} $*"; }
info()    { echo -e "  ${C}→${D} $*"; }
ask()     { echo -e "\n  ${W}$*${D}"; }

run() {
    if $DRY_RUN; then
        info "[dry-run] $*"
    else
        "$@"
    fi
}

require_root_or_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        fail "This script requires sudo or root."
        exit 1
    fi
}

# ─── OS Detection ──────────────────────────────────────────────────────────────
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        fail "Cannot detect OS: /etc/os-release not found."
        exit 1
    fi
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_CODENAME="${VERSION_CODENAME:-}"

    if ! command -v apt &>/dev/null; then
        fail "This installer requires apt (Debian/Ubuntu)."
        exit 1
    fi

    ok "Detected: ${OS_NAME}"
    if [[ "$OS_CODENAME" ]]; then
        info "Codename: ${OS_CODENAME}"
    fi
}

# ─── User Questions ────────────────────────────────────────────────────────────
ask_questions() {
    # Theme list comes straight from the JSON palettes
    ask "Which color theme should be applied first?"
    local ids=() names=()
    for f in "$REPO_DIR"/.config/themes/*.json; do
        ids+=("$(basename "$f" .json)")
        names+=("$(python3 -c 'import json,sys; t=json.load(open(sys.argv[1])); print(t["name"], "(" + t["mode"] + ")")' "$f")")
    done
    select THEME_NAME in "${names[@]}"; do
        if [[ -n "$THEME_NAME" ]]; then
            THEME_ID="${ids[$((REPLY - 1))]}"
            break
        fi
        warn "Please choose 1–${#names[@]}."
    done
    ok "Theme: ${THEME_ID}"

    ask "Install optional extras? (kitty, blueman, htop, thunar, pavucontrol)"
    select EXTRAS_CHOICE in "Yes" "No"; do
        case "$EXTRAS_CHOICE" in
            Yes|No) break ;;
            *) warn "Please choose 1 or 2." ;;
        esac
    done

    ask "Download Nerd Fonts (CaskaydiaCove + JetBrainsMono, ~30 MB)? Needed for bar/menu icons."
    select FONTS_CHOICE in "Yes" "No"; do
        case "$FONTS_CHOICE" in
            Yes|No) break ;;
            *) warn "Please choose 1 or 2." ;;
        esac
    done
}

# ─── Package Lists ────────────────────────────────────────────────────────────
PKGS_HYPRLAND=(
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt6-wayland
)

PKGS_BASE=(
    # bar / launcher / notifications / wallpaper
    waybar wofi rofi sway-notification-center swaybg
    # terminal & tools shown in the menus
    alacritty fastfetch librespeed-cli
    # screenshots, clipboard, media & hardware keys
    grim slurp grimshot wl-clipboard playerctl brightnessctl
    # audio
    pipewire pipewire-pulse wireplumber pulseaudio-utils
    # network / bluetooth applets used by waybar
    network-manager network-manager-gnome blueman
    # theme system & wallpaper transition (python + GTK layer-shell)
    python3 python3-pil python3-gi python3-gi-cairo
    gir1.2-gtk-3.0 gir1.2-gtklayershell-0.1 libnotify-bin
    # GTK/icon theming targets of theme-apply
    adwaita-icon-theme libgtk-3-bin libglib2.0-bin dconf-cli
    # fonts
    fonts-jetbrains-mono fonts-noto fonts-noto-color-emoji
    # misc
    polkitd xdg-utils xdg-user-dirs curl unzip
)

PKGS_EXTRAS=(
    kitty
    htop
    thunar
    thunar-archive-plugin
    file-roller
    pavucontrol
)

build_pkg_list() {
    PKGS=("${PKGS_BASE[@]}")
    if [[ "$EXTRAS_CHOICE" == "Yes" ]]; then
        PKGS+=("${PKGS_EXTRAS[@]}")
    fi
}

# ─── Repository Setup ─────────────────────────────────────────────────────────
# hyprland.conf uses the windowrule{}/layerrule{} block syntax and `hyprctl eval`,
# which need Hyprland ≥ 0.54. On Debian stable that lives in backports.
HYPR_APT_OPTS=()
setup_repos() {
    step "Setting up package repositories"

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID_LIKE" == *ubuntu* ]]; then
        if ! grep -rq "hyprland" /etc/apt/sources.list.d/ 2>/dev/null; then
            info "Adding Hyprland PPA..."
            run $SUDO add-apt-repository -y ppa:hyprland-contrib/hyprland || true
        else
            ok "Hyprland PPA already present"
        fi
    elif [[ "$OS_ID" == "debian" && -n "$OS_CODENAME" ]]; then
        local bp="${OS_CODENAME}-backports"
        if ! grep -rqs "$bp" /etc/apt/sources.list /etc/apt/sources.list.d/; then
            info "Enabling ${bp}..."
            run $SUDO tee /etc/apt/sources.list.d/chrysalis-backports.list >/dev/null \
                <<< "deb http://deb.debian.org/debian ${bp} main contrib non-free non-free-firmware"
        else
            ok "${bp} already enabled"
        fi
        HYPR_APT_OPTS=(-t "$bp")
    fi

    run $SUDO apt update -qq
    ok "Repository index updated"
}

# ─── Installation ────────────────────────────────────────────────────────────
install_packages() {
    step "Installing packages"

    filter_available() {
        local out=()
        for pkg in "$@"; do
            if apt-cache show "$pkg" &>/dev/null; then
                out+=("$pkg")
            else
                warn "Not available in apt: $pkg (skipping)"
            fi
        done
        printf '%s\n' "${out[@]}"
    }

    mapfile -t HYPR_INSTALLABLE < <(filter_available "${PKGS_HYPRLAND[@]}")
    mapfile -t INSTALLABLE      < <(filter_available "${PKGS[@]}")

    info "Hyprland packages: ${#HYPR_INSTALLABLE[@]}, other packages: ${#INSTALLABLE[@]}"
    run $SUDO apt install -y "${HYPR_APT_OPTS[@]}" "${HYPR_INSTALLABLE[@]}"
    run $SUDO apt install -y "${INSTALLABLE[@]}"
    ok "Packages installed"
}

# ─── Fonts ───────────────────────────────────────────────────────────────────
install_fonts() {
    [[ "$FONTS_CHOICE" == "Yes" ]] || return 0
    step "Installing Nerd Fonts"
    local base="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    for f in CascadiaCode JetBrainsMono; do
        if fc-list 2>/dev/null | grep -qi "${f/CascadiaCode/CaskaydiaCove} Nerd Font"; then
            ok "$f Nerd Font already installed"
            continue
        fi
        info "Downloading $f.zip..."
        run mkdir -p "$FONTS/$f-nerd"
        run curl -fsSL "$base/$f.zip" -o "/tmp/$f.zip"
        run unzip -oq "/tmp/$f.zip" -d "$FONTS/$f-nerd"
        run rm -f "/tmp/$f.zip"
        ok "$f Nerd Font installed"
    done
    run fc-cache -f
}

# ─── Config Deployment ───────────────────────────────────────────────────────
link() {  # link SRC DST — symlink, backing up anything that is already there
    local src="$1" dst="$2" name="${3:-$(basename "$2")}"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        ok "Already linked: $name"
    elif [[ -e "$dst" || -L "$dst" ]]; then
        warn "Backing up existing: $name → $name.bak"
        run mv "$dst" "${dst}.bak"
        run ln -s "$src" "$dst"
        ok "Linked: $name"
    else
        run ln -s "$src" "$dst"
        ok "Linked: $name"
    fi
}

deploy_configs() {
    step "Deploying configuration files"
    run mkdir -p "$CFG" "$BIN" "$CFG/wallpapers" "$HOME/Pictures/Wallpapers"

    # Config directories: everything under .config/ except wallpapers (copied below)
    for src in "$REPO_DIR"/.config/*/; do
        local d; d="$(basename "$src")"
        [[ "$d" == "wallpapers" ]] && continue
        link "${src%/}" "$CFG/$d" "$d"
    done

    # Scripts
    for src in "$REPO_DIR"/.local/bin/*; do
        link "$src" "$BIN/$(basename "$src")" "bin/$(basename "$src")"
    done

    # Default wallpaper is copied, not linked: wallpaper-gen writes into this dir
    for img in "$REPO_DIR"/.config/wallpapers/*; do
        [[ -e "$CFG/wallpapers/$(basename "$img")" ]] || run cp "$img" "$CFG/wallpapers/"
    done
    ok "Wallpapers copied"
}

# ─── Theme Bootstrap ─────────────────────────────────────────────────────────
apply_theme() {
    step "Applying initial theme: $THEME_ID"

    # mesh-gradient wallpaper per theme, then the default wallpaper symlink
    run python3 "$BIN/wallpaper-gen"
    if [[ ! -e "$CFG/wallpapers/current" ]]; then
        run ln -sfn "$CFG/wallpapers/house-garden.png" "$CFG/wallpapers/current"
    fi

    # theme-apply reloads hyprland/waybar/swaync when they run; outside a
    # session those calls just fail quietly and only the files are written
    run python3 "$BIN/theme-apply" "$THEME_ID" --quiet
    ok "Theme '$THEME_ID' applied"
}

# ─── Shell Profile ────────────────────────────────────────────────────────────
setup_profile() {
    step "Setting up shell profile"

    PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -qF "$PROFILE_LINE" "$rc"; then
            run bash -c "echo '$PROFILE_LINE' >> '$rc'"
            ok "Updated $rc"
        fi
    done
}

# ─── Summary ─────────────────────────────────────────────────────────────────
print_summary() {
    echo -e "\n${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${D}"
    echo -e "${W}  Installation complete!${D}"
    echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${D}\n"
    echo -e "  ${C}Theme:${D} $THEME_ID"
    echo -e ""
    echo -e "  ${W}Next steps:${D}"
    echo -e "  ${Y}→${D} Log out and select 'Hyprland' in your display manager, or:"
    echo -e "    ${C}Hyprland${D} from a TTY"
    echo -e ""
    echo -e "  ${W}Main menu:${D}       ${C}Super + Alt + Space${D}"
    echo -e "  ${W}App launcher:${D}    ${C}Super + Space${D}"
    echo -e "  ${W}Switch theme:${D}    ${C}theme-apply <id>${D}   (theme-apply --list)"
    echo -e "  ${W}Set wallpaper:${D}   ${C}wallpaper-set <image>${D}"
    echo -e ""

    if $DRY_RUN; then
        echo -e "  ${Y}[DRY RUN — no changes were made]${D}\n"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    print_header

    if $DRY_RUN; then
        warn "Running in DRY RUN mode — no changes will be made\n"
    fi

    require_root_or_sudo
    detect_os
    ask_questions
    build_pkg_list
    setup_repos
    install_packages
    install_fonts
    deploy_configs
    apply_theme
    setup_profile
    print_summary
}

main "$@"

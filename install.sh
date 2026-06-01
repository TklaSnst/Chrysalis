#!/usr/bin/env bash
# =============================================================================
# betterdeb — automated installer
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

# ─── Helpers ──────────────────────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${M}"
    cat << 'BANNER'
 _          _   _            _      _
| |__   ___| |_| |_ ___ _ __| |  __| | ___| |__
| '_ \ / _ \ __| __/ _ \ '__| | / _` |/ _ \ '_ \
| |_) |  __/ |_| ||  __/ |  | || (_| |  __/ |_) |
|_.__/ \___|\__|\__\___|_|  |_| \__,_|\___|_.__/

BANNER
    echo -e "${D}  ${C}A clean Debian/Ubuntu Wayland setup${D}"
    echo -e "  ${W}https://github.com/TklaSnst/betterdeb${D}\n"
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
    OS_VERSION="${VERSION_CODENAME:-${VERSION_ID:-}}"

    if ! command -v apt &>/dev/null; then
        fail "This installer requires apt (Debian/Ubuntu)."
        exit 1
    fi

    ok "Detected: ${OS_NAME}"
    if [[ "$OS_VERSION" ]]; then
        info "Codename: ${OS_VERSION}"
    fi
}

# ─── User Questions ────────────────────────────────────────────────────────────
ask_questions() {
    # WM choice
    ask "Which window manager would you like to install?"
    select WM_CHOICE in "Hyprland" "Sway" "Both"; do
        case "$WM_CHOICE" in
            Hyprland|Sway|Both) break ;;
            *) warn "Please choose 1, 2, or 3." ;;
        esac
    done
    ok "Window manager: ${WM_CHOICE}"

    # Terminal
    ask "Which terminal emulator?"
    select TERM_CHOICE in "kitty" "alacritty" "foot"; do
        case "$TERM_CHOICE" in
            kitty|alacritty|foot) break ;;
            *) warn "Please choose 1, 2, or 3." ;;
        esac
    done
    ok "Terminal: ${TERM_CHOICE}"

    # Default theme
    ask "Which default color theme?"
    select THEME_CHOICE in "Catppuccin Mocha" "Nord" "Everforest Dark" "Gruvbox Dark" "Tokyo Night" "Kanagawa"; do
        case "$THEME_CHOICE" in
            "Catppuccin Mocha") THEME_ID="catppuccin"; break ;;
            "Nord")             THEME_ID="nord";        break ;;
            "Everforest Dark")  THEME_ID="everforest";  break ;;
            "Gruvbox Dark")     THEME_ID="gruvbox";     break ;;
            "Tokyo Night")      THEME_ID="tokyonight";  break ;;
            "Kanagawa")         THEME_ID="kanagawa";    break ;;
            *) warn "Please choose 1–6." ;;
        esac
    done
    ok "Theme: ${THEME_ID}"

    # Optional extras
    ask "Install optional extras? (thunar, pavucontrol, blueman)"
    select EXTRAS_CHOICE in "Yes" "No"; do
        case "$EXTRAS_CHOICE" in
            Yes|No) break ;;
            *) warn "Please choose 1 or 2." ;;
        esac
    done
}

# ─── Package Lists ────────────────────────────────────────────────────────────
PKGS_BASE=(
    waybar rofi cava grim slurp wl-clipboard
    wl-color-picker hyprpicker
    playerctl pipewire wireplumber
    python3 python3-yaml
    fonts-jetbrains-mono
    papirus-icon-theme
    swaybg hypridle
    dunst libnotify-bin
    xdg-utils xdg-user-dirs
    brightnessctl
    network-manager
    network-manager-gnome
)

PKGS_HYPRLAND=(
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    hyprlock
    qt6-wayland
)

PKGS_SWAY=(
    sway
    swaylock
    swayidle
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
)

PKGS_KITTY=(kitty)
PKGS_ALACRITTY=(alacritty)
PKGS_FOOT=(foot)

PKGS_EXTRAS=(
    thunar
    thunar-archive-plugin
    file-roller
    pavucontrol
    blueman
)

build_pkg_list() {
    PKGS=("${PKGS_BASE[@]}")

    case "$WM_CHOICE" in
        Hyprland) PKGS+=("${PKGS_HYPRLAND[@]}") ;;
        Sway)     PKGS+=("${PKGS_SWAY[@]}") ;;
        Both)     PKGS+=("${PKGS_HYPRLAND[@]}" "${PKGS_SWAY[@]}") ;;
    esac

    case "$TERM_CHOICE" in
        kitty)     PKGS+=("${PKGS_KITTY[@]}") ;;
        alacritty) PKGS+=("${PKGS_ALACRITTY[@]}") ;;
        foot)      PKGS+=("${PKGS_FOOT[@]}") ;;
    esac

    [[ "$EXTRAS_CHOICE" == "Yes" ]] && PKGS+=("${PKGS_EXTRAS[@]}")
}

# ─── PPA / Repository Setup ───────────────────────────────────────────────────
setup_repos() {
    step "Setting up package repositories"

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID_LIKE" == *ubuntu* ]]; then
        # Hyprland is not in Ubuntu repos — use the community PPA
        if [[ "$WM_CHOICE" == "Hyprland" || "$WM_CHOICE" == "Both" ]]; then
            if ! grep -r "hyprland" /etc/apt/sources.list.d/ &>/dev/null 2>&1; then
                info "Adding Hyprland PPA..."
                run $SUDO add-apt-repository -y ppa:hyprland-contrib/hyprland || true
            else
                ok "Hyprland PPA already present"
            fi
        fi
    fi

    run $SUDO apt update -qq
    ok "Repository index updated"
}

# ─── Installation ────────────────────────────────────────────────────────────
install_packages() {
    step "Installing packages"
    info "Total packages: ${#PKGS[@]}"

    # Filter out unavailable packages silently
    INSTALLABLE=()
    for pkg in "${PKGS[@]}"; do
        if apt-cache show "$pkg" &>/dev/null 2>&1; then
            INSTALLABLE+=("$pkg")
        else
            warn "Not available in apt: $pkg (skipping)"
        fi
    done

    run $SUDO apt install -y "${INSTALLABLE[@]}"
    ok "Packages installed"
}

# ─── Config Deployment ───────────────────────────────────────────────────────
deploy_configs() {
    step "Deploying configuration files"

    mkdir -p "$CFG"
    mkdir -p "$HOME/Pictures/Wallpapers"
    mkdir -p "$CFG/wallpapers"

    # Symlink each config directory
    local DIRS=(kitty sway themes wofi rofi scripts)
    [[ "$WM_CHOICE" == "Hyprland" || "$WM_CHOICE" == "Both" ]] && DIRS+=(hyprland)

    for d in "${DIRS[@]}"; do
        SRC="$REPO_DIR/.config/$d"
        DST="$CFG/$d"
        if [[ -d "$SRC" ]]; then
            if [[ -L "$DST" ]]; then
                ok "Already linked: $d"
            elif [[ -d "$DST" ]]; then
                warn "Backing up existing: $d → $d.bak"
                run mv "$DST" "${DST}.bak"
                run ln -s "$SRC" "$DST"
            else
                run ln -s "$SRC" "$DST"
                ok "Linked: $d"
            fi
        fi
    done

    # Waybar lives in repo root waybar/
    SRC="$REPO_DIR/waybar"
    DST="$CFG/waybar"
    if [[ -L "$DST" ]]; then
        ok "Already linked: waybar"
    elif [[ -d "$DST" ]]; then
        warn "Backing up existing: waybar → waybar.bak"
        run mv "$DST" "${DST}.bak"
        run ln -s "$SRC" "$DST"
    else
        run ln -s "$SRC" "$DST"
        ok "Linked: waybar"
    fi

    # Wofi styles
    SRC="$REPO_DIR/.config/wofi"
    DST="$CFG/wofi"
    # (already handled above in the loop)

    ok "Configs deployed"
}

# ─── Theme Bootstrap ─────────────────────────────────────────────────────────
apply_theme() {
    step "Applying initial theme: $THEME_ID"

    SWITCH="$CFG/themes/switch.sh"
    if [[ -f "$SWITCH" ]]; then
        run bash "$SWITCH" "$THEME_ID"
        ok "Theme '$THEME_ID' applied"
    else
        warn "switch.sh not found, skipping theme generation"
    fi
}

# ─── Shell Profile ────────────────────────────────────────────────────────────
setup_profile() {
    step "Setting up shell profile"

    PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -qF "$PROFILE_LINE" "$rc"; then
            echo "$PROFILE_LINE" >> "$rc"
            ok "Updated $rc"
        fi
    done
}

# ─── Summary ─────────────────────────────────────────────────────────────────
print_summary() {
    echo -e "\n${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${D}"
    echo -e "${W}  Installation complete!${D}"
    echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${D}\n"
    echo -e "  ${C}Window manager:${D} $WM_CHOICE"
    echo -e "  ${C}Terminal:       ${D} $TERM_CHOICE"
    echo -e "  ${C}Theme:          ${D} $THEME_ID"
    echo -e ""
    echo -e "  ${W}Next steps:${D}"

    if [[ "$WM_CHOICE" == "Hyprland" || "$WM_CHOICE" == "Both" ]]; then
        echo -e "  ${Y}→${D} Log out and select 'Hyprland' in your display manager, or:"
        echo -e "    ${C}exec Hyprland${D} from a TTY"
    fi
    if [[ "$WM_CHOICE" == "Sway" || "$WM_CHOICE" == "Both" ]]; then
        echo -e "  ${Y}→${D} Type ${C}sway${D} in a TTY to start Sway"
    fi

    echo -e ""
    echo -e "  ${W}To switch themes:${D}  ${C}~/.config/themes/switch.sh <theme>${D}"
    echo -e "  ${W}Control plane:${D}     ${C}Super + Alt + Space${D}"
    echo -e "  ${W}App launcher:${D}      ${C}Super + Space${D}"
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
    deploy_configs
    apply_theme
    setup_profile
    print_summary
}

main "$@"

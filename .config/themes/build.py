#!/usr/bin/env python3
"""betterdeb theme builder — reads YAML theme, renders templates, writes configs."""

import sys
import yaml
from pathlib import Path
from string import Template

BASE     = Path(__file__).parent.resolve()   # ~/.config/themes/
TMPL_DIR = BASE / "templates"
HOME     = Path.home()
CFG      = HOME / ".config"

# template file → output path
TARGETS: dict[str, Path] = {
    "waybar-colors.css.tpl":    CFG / "waybar/colors/colors.css",
    "hyprland-theme.conf.tpl":  CFG / "hyprland/theme.conf",
    "sway-colors.conf.tpl":     CFG / "sway/colors.conf",
    "kitty-theme.conf.tpl":     CFG / "kitty/theme.conf",
    "wofi-colors.css.tpl":      CFG / "wofi/colors.css",
    "rofi-theme.rasi.tpl":      CFG / "rofi/theme.rasi",
    "gtk-settings.ini.tpl":     CFG / "gtk-3.0/settings.ini",
}

GTK_THEMES: dict[str, tuple[str, str]] = {
    "catppuccin": ("Catppuccin-Mocha-Standard-Blue-Dark", "Papirus-Dark"),
    "nord":       ("Nordic",                               "Papirus-Dark"),
    "everforest": ("Everforest-Dark-B",                   "Papirus-Dark"),
    "gruvbox":    ("Gruvbox-Dark",                        "Papirus-Dark"),
    "tokyonight": ("Tokyonight-Storm",                    "Papirus-Dark"),
    "kanagawa":   ("Kanagawa",                            "Papirus-Dark"),
}


def _hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _rgba_css(h: str, alpha: float = 0.92) -> str:
    r, g, b = _hex_to_rgb(h)
    return f"rgba({r},{g},{b},{alpha})"


def _hypr_rgba(h: str, alpha: float = 0.30) -> str:
    """#rrggbb + float alpha → rrggbbaa (Hyprland color format)."""
    aa = format(round(alpha * 255), "02x")
    return h.lstrip("#") + aa


def build_context(theme: dict, theme_name: str) -> dict:
    ctx: dict = dict(theme)

    # Semi-transparent module background for waybar
    ctx["module_bg"] = _rgba_css(theme["bg_panel"], 0.92)

    # Plain hex (no #) for Hyprland
    for key in ("bg", "fg", "accent", "border", "red", "green", "yellow",
                "blue", "purple", "cyan", "bg_window", "bg_panel"):
        ctx[f"{key}_hex"] = theme[key].lstrip("#")

    # Shadow in Hyprland format (black at 30% opacity)
    ctx["shadow_hex"] = _hypr_rgba("#000000", 0.30)

    # GTK theme mapping
    gtk_theme, gtk_icons = GTK_THEMES.get(theme_name, ("Adwaita-dark", "Papirus-Dark"))
    ctx["gtk_theme"]      = gtk_theme
    ctx["gtk_icon_theme"] = gtk_icons

    return ctx


def render_templates(ctx: dict) -> list[str]:
    errors: list[str] = []
    for tpl_name, out_path in TARGETS.items():
        tpl_file = TMPL_DIR / tpl_name
        if not tpl_file.exists():
            print(f"  [skip] {tpl_name} — template not found")
            continue
        out_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            rendered = Template(tpl_file.read_text()).substitute(ctx)
            out_path.write_text(rendered)
            rel = out_path.relative_to(HOME)
            print(f"  [ok]   {rel}")
        except KeyError as exc:
            errors.append(f"  [err]  {tpl_name}: missing variable {exc}")
    return errors


def apply_gtk(ctx: dict) -> None:
    import shutil, subprocess
    if not shutil.which("gsettings"):
        return
    settings = [
        ("org.gnome.desktop.interface", "gtk-theme",     ctx["gtk_theme"]),
        ("org.gnome.desktop.interface", "icon-theme",    ctx["gtk_icon_theme"]),
        ("org.gnome.desktop.interface", "color-scheme",  "prefer-dark"),
    ]
    for schema, key, value in settings:
        try:
            subprocess.run(["gsettings", "set", schema, key, value],
                           check=True, capture_output=True)
        except subprocess.CalledProcessError:
            pass  # may fail without a D-Bus session


def mirror_gtk4(gtk3_path: Path) -> None:
    gtk4 = gtk3_path.parent.parent / "gtk-4.0" / "settings.ini"
    if gtk3_path.exists():
        gtk4.parent.mkdir(parents=True, exist_ok=True)
        gtk4.write_text(gtk3_path.read_text())
        print(f"  [ok]   .config/gtk-4.0/settings.ini")


def main() -> None:
    current = BASE / "current.yaml"
    if not current.exists():
        print("Error: current.yaml not found.", file=sys.stderr)
        print("Run: ln -sf ~/.config/themes/<theme>.yaml ~/.config/themes/current.yaml",
              file=sys.stderr)
        sys.exit(1)

    with open(current) as f:
        theme = yaml.safe_load(f)

    try:
        theme_name = current.resolve().stem
    except Exception:
        theme_name = "unknown"

    print(f"Building theme: {theme_name}")
    ctx    = build_context(theme, theme_name)
    errors = render_templates(ctx)
    mirror_gtk4(CFG / "gtk-3.0/settings.ini")
    apply_gtk(ctx)

    if errors:
        print("\nWarnings:")
        for e in errors:
            print(e)

    print(f"\nTheme '{theme_name}' applied.")


if __name__ == "__main__":
    main()

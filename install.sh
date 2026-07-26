#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link() {
    local src="$DOTFILES_DIR/$1"
    local dst="$HOME/$1"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        echo "  backed up: ~/$1"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    echo "  linked: ~/$1"
}

echo "Installing dotfiles..."
echo ""

# Shell
link .bashrc
link .profile
link .gitconfig
link .npmrc

# Sway
link .config/sway/config

# Waybar
link .config/waybar/config.jsonc
link .config/waybar/style.css

# Terminal & notifications
link .config/foot/foot.ini
link .config/mako/config
link .config/kanshi/config
link .config/swayr/config.toml

# System
link .config/btop/btop.conf
link .config/libinput-gestures.conf

# Themes
link .config/gtk-3.0/settings.ini
link .config/gtk-3.0/gtk.css
link .config/gtk-4.0/settings.ini
link .config/qt5ct/qt5ct.conf
link .config/qt6ct/qt6ct.conf

# Screenshot tools
link .config/flameshot/flameshot.ini
link .config/swappy/config

# Audio
link .config/wireplumber/wireplumber.conf.d/50-no-suspend.conf
link .config/xdg-desktop-portal-wlr/config

# MIME types
link .config/mimeapps.list
link .config/user-dirs.dirs
link .config/user-dirs.locale

# Scripts
link .local/bin/temp_monitor.sh

echo ""
echo "Done! Backups saved to: $BACKUP_DIR"
echo "Restart sway or run: swaymsg reload"

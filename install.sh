#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }

# --- Package Installation ---
install_packages() {
    if ! command -v pacman &>/dev/null; then
        warn "Not on Arch Linux — skipping package installation"
        return
    fi

    info "Installing packages..."

    # Core packages
    local pacman_pkgs=(
        # Wayland/Sway
        sway swayidle swaylock swaybg swayr
        waybar wofi mako grim slurp satty
        kanshi nwg-displays libinput-gestures

        # Terminal
        foot

        # Audio
        pipewire pipewire-pulse wireplumber
        pavucontrol wpctl

        # Utilities
        fzf zoxide eza bat
        brightnessctl playerctl
        copyq flameshot swappy
        btop htop
        nm-applet blueman
        Thunar
        nextcloud-client

        # Fonts
        ttf-jetbrains-mono-nerd
        noto-fonts noto-fonts-emoji

        # Dev
        git github-cli
        nodejs npm
        python python-pip
        docker

        # Misc
        openssh gnupg
        unzip wget curl
        tesseract tesseract-data-deu tesseract-data-eng
        qalculate-gtk
        batsignal
    )

    # AUR packages (via yay)
    local aur_pkgs=(
        vesktop
        google-chrome
        steam
        heroic-games-launcher-bin
        rustdesk-bin
        teamviewer
        stremio
        filezilla
        normcap
        impala
    )

    # Install pacman packages
    local missing_pkgs=()
    for pkg in "${pacman_pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        info "Installing ${#missing_pkgs[@]} pacman packages..."
        sudo pacman -S --noconfirm "${missing_pkgs[@]}"
    else
        info "All pacman packages already installed"
    fi

    # Install AUR packages
    if command -v yay &>/dev/null; then
        local missing_aur=()
        for pkg in "${aur_pkgs[@]}"; do
            if ! yay -Qi "$pkg" &>/dev/null; then
                missing_aur+=("$pkg")
            fi
        done

        if [ ${#missing_aur[@]} -gt 0 ]; then
            info "Installing ${#missing_aur[@]} AUR packages..."
            yay -S --noconfirm "${missing_aur[@]}"
        else
            info "All AUR packages already installed"
        fi
    else
        warn "yay not found — skipping AUR packages"
        warn "Install yay: git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si"
    fi
}

# --- Symlink Files ---
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

# --- Main ---
echo ""
echo "  dotfiles installer"
echo "  =================="
echo ""

if [ "${1:-}" != "--no-packages" ]; then
    install_packages
fi

echo ""
info "Symlinking configs..."

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

# Wofi
link .config/wofi/config
link .config/wofi/style.css

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
link .config/gtk-3.0/bookmarks
link .config/gtk-4.0/settings.ini
link .config/qt5ct/qt5ct.conf
link .config/qt6ct/qt6ct.conf

# Screenshot tools
link .config/flameshot/flameshot.ini
link .config/swappy/config

# Audio
link .config/wireplumber/wireplumber.conf.d/50-no-suspend.conf
link .config/xdg-desktop-portal-wlr/config

# Clipboard
link .config/copyq/copyq.conf
link .config/copyq/copyq-commands.ini
link .config/copyq/copyq_tabs.ini
link .config/copyq/copyq-filter.ini

# VS Code
link .config/Code/User/settings.json

# MIME types
link .config/mimeapps.list
link .config/user-dirs.dirs
link .config/user-dirs.locale

echo ""
info "Done!"
echo "  Backups: $BACKUP_DIR"
echo "  Restart: swaymsg reload"
echo ""

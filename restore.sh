#!/bin/bash
set -euo pipefail

# restore.sh — Pull dotfiles from GitHub and run install.sh
# Usage: bash restore.sh

REPO="https://github.com/Michi4/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

echo ""
echo "  dotfiles restore"
echo "  ================"
echo ""

# Check for git
if ! command -v git &>/dev/null; then
    echo "[x] git not found. Install it first:"
    echo "    Arch:  sudo pacman -S git"
    echo "    Ubuntu: sudo apt install git"
    exit 1
fi

# Clone or update repo
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "[+] Updating existing dotfiles..."
    git -C "$DOTFILES_DIR" pull
else
    echo "[+] Cloning dotfiles..."
    git clone "$REPO" "$DOTFILES_DIR"
fi

# Run installer
echo ""
echo "[+] Running install.sh..."
bash "$DOTFILES_DIR/install.sh" "$@"

echo ""
echo "[+] Restore complete!"

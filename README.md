# dotfiles

My Sway (Wayland) configuration.

## Fresh Machine Setup

```bash
git clone https://github.com/Michi4/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Skip package installation (just symlinks): `./install.sh --no-packages`

Restore without cloning first:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Michi4/dotfiles/main/restore.sh)
```

## What's Included

| Config | Tool |
|--------|------|
| `sway/config` | Sway WM - keybinds, workspace rules, autostart |
| `waybar/` | Status bar + custom scripts |
| `wofi/` | App launcher (Nord themed) |
| `foot/foot.ini` | Terminal emulator |
| `mako/config` | Notification daemon |
| `kanshi/config` | Monitor profiles (docked/basement/mobile) |
| `swayr/config.toml` | Window switcher |
| `btop/btop.conf` | System monitor (Nord theme) |
| `copyq/` | Clipboard manager |
| `gtk-3.0/`, `gtk-4.0/`, `qt5ct/`, `qt6ct/` | Dark theme (Adwaita-dark) |
| `flameshot/`, `swappy/` | Screenshot tools |
| `wireplumber/` | Audio (no ALSA suspend) |
| `vesktop/` | Discord + Spotify-Discord theme |
| `Code/User/` | VS Code settings |
| `systemd/user/` | OpenVPN, PipeWire services |
| `autostart/` | Nextcloud, JetBrains Toolbox, Stremio |
| `.bashrc`, `.profile` | Shell config (fzf, zoxide, eza) |
| `bin/` | Laravel Valet helpers |

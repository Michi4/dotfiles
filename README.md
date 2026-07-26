# dotfiles

My personal Sway (Wayland) desktop configuration.

## Setup

```bash
git clone https://github.com/Michi4/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh  # or manually symlink
```

## What's Included

| Config | Tool |
|--------|------|
| `sway/config` | Sway WM - keybinds, workspace rules, autostart |
| `waybar/` | Status bar + 13 custom scripts (media, weather, network) |
| `foot/foot.ini` | Terminal emulator |
| `mako/config` | Notification daemon |
| `kanshi/config` | Monitor profiles (docked/basement/mobile) |
| `swayr/config.toml` | Window switcher |
| `btop/btop.conf` | System monitor |
| `gtk-3.0/`, `gtk-4.0/`, `qt5ct/`, `qt6ct/` | Dark theme (Adwaita-dark) |
| `flameshot/`, `swappy/` | Screenshot tools |
| `wireplumber/` | Audio (no ALSA suspend) |
| `vesktop/` | Discord + Spotify-Discord theme |
| `systemd/user/` | OpenVPN, PipeWire services |
| `autostart/` | Nextcloud, JetBrains Toolbox, Stremio |
| `.bashrc`, `.profile` | Shell config (fzf, zoxide, eza) |
| `bin/` | Laravel Valet helpers |
| `.local/bin/` | Temperature monitor |

## Hardware

- Laptop: eDP-1 (1920x1080, scale 1.2)
- Monitors: DP-1 (Lenovo C24-25), HDMI-A-1 (Samsung SMBX2235)
- Keyboard: German (de) layout
- Theme: Dark mode (Nord colors)

## Scripts

All waybar scripts are in `.config/waybar/scripts/`:
- `media-slot.sh` - Multi-player media display with dynamic width allocation
- `weather.sh` - Open-Meteo API for Linz, Austria
- `network.sh` - WiFi/Ethernet status
- `clock.sh` - Date/time with calendar tooltip
- `battery.sh` - Battery status with critical/warning alerts
- `temp_monitor.sh` - CPU temp monitoring with Sway border alerts

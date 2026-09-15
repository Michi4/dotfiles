#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History: big file, no duplicates, share across terminals
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Append to history file immediately (not just on exit)
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

alias wpass='nmcli device wifi show-password'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export GTK_THEME=Adwaita:dark

export PATH="$PATH:$HOME/.config/composer/vendor/bin:$HOME/.cargo/bin"

#alias mountwork='gocryptfs ~/hider/.work_vault ~/hider/work'
#alias umountwork='fusermount -u ~/hider/work'

# Better bash completion
[[ -r "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"

# FZF (Fuzzy Finder for history and files)
eval "$(fzf --bash)"

# Zoxide (Smarter 'cd' that remembers your directories)
eval "$(zoxide init bash)"
# cd uses the real builtin for existing paths (incl. -, --flags),
# zoxide fuzzy-matching only otherwise (else: "no match found" confusion)
cd() {
  if [ $# -eq 0 ] || [ "$1" = "-" ] || case "$1" in -*) true;; *) false;; esac || [ -d "$1" ]; then
    builtin cd "$@"
  else
    z "$@"
  fi
}

# Eza (Better 'ls' with colors)
alias ls="eza --icons=always --color=always"
alias ll="eza -l --icons=always --color=always"

if [ -z "$SSH_AUTH_SOCK" ]; then
   eval $(ssh-agent -s) > /dev/null
fi

export MOZ_ENABLE_WAYLAND=1
export THUNDERBIRD_WAYLAND=1
alias reset-dock='sudo sh -c "echo -n \"usb2\" > /sys/bus/usb/drivers/usb/unbind && sleep 1 && echo -n \"usb2\" > /sys/bus/usb/drivers/usb/bind"'

# Fix Lenovo dock USB (Renesas controller) after using with Windows — no reboot needed
alias fixdock='sudo /usr/local/bin/renesas-usb-fix.sh'
# opencode-vpn — run opencode inside a WireGuard network namespace.
# Numbers map to ~/.wireguard/proton<N>.conf (1 -> proton.conf):
#   opencode-vpn 1 [args...]  -> namespace 'vpn'
#   opencode-vpn 2 [args...]  -> namespace 'vpn2'
#   opencode-vpn status       -> tunnel health table (no password needed)
#   opencode-vpn [args...]    -> interactive picker, then run with args
_OPENCODE_VPN_BIN="$HOME/.local/bin/vpn-netns"
_OPENCODE_VPN_STALE_AFTER=180

_opencode_vpn_resolve_opencode() {
    local c
    for c in "$HOME/.opencode/bin/opencode" "$HOME/.opencode/opencode" /usr/bin/opencode; do
        if [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    done
    c="$(command -v opencode 2>/dev/null || true)"
    if [ -n "$c" ]; then
        echo "$c"
        return 0
    fi
    return 1
}

_opencode_vpn_ns_up() {
    # $1 = namespace name. Works unprivileged; falls back to a
    # passwordless sudoers-covered probe when the list is not visible.
    ip netns list 2>/dev/null | grep -qE "^$1([[:space:]]|$)" \
        || sudo -n ip netns exec "$1" true 2>/dev/null
}

_opencode_vpn_handshake_age() {
    # $1 = namespace -> seconds since last handshake, or "never" (passwordless via sudoers).
    local epoch now
    epoch="$(sudo -n ip netns exec "$1" wg show wg0 latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')"
    if [ -z "${epoch:-}" ] || [ "$epoch" = "0" ]; then
        echo "never"
        return 0
    fi
    now="$(date +%s)"
    echo "$(( now - epoch ))"
}

_opencode_vpn_tunnel_ip() {
    # $1 = namespace -> tunnel IPv4 (passwordless via sudoers).
    sudo -n ip netns exec "$1" ip -4 -o addr show dev wg0 2>/dev/null \
        | awk '{print $4}' | cut -d/ -f1 | head -n 1
}

_opencode_vpn_health() {
    # $1 = namespace -> one-line health summary.
    local ip age
    if ! _opencode_vpn_ns_up "$1"; then
        echo "DOWN"
        return 0
    fi
    ip="$(_opencode_vpn_tunnel_ip "$1")"
    age="$(_opencode_vpn_handshake_age "$1")"
    if [ -n "$ip" ] && [ "$age" != "never" ] && [ "$age" -le "$_OPENCODE_VPN_STALE_AFTER" ]; then
        echo "UP   tunnel ${ip}  handshake ${age}s ago"
    elif [ -n "$ip" ]; then
        echo "UP?  tunnel ${ip}  handshake ${age} (stale!)"
    else
        echo "UP?  no tunnel IP"
    fi
}

_opencode_vpn_nums() {
    # VPN numbers available on this host, from ~/.wireguard/proton[N].conf.
    local f n
    [ -f "$HOME/.wireguard/proton.conf" ] && echo 1
    for f in "$HOME"/.wireguard/proton[0-9]*.conf; do
        [ -e "$f" ] || continue
        n="${f##*/proton}"
        n="${n%.conf}"
        [[ "$n" =~ ^[0-9]+$ ]] && echo "$n"
    done | sort -n -u
}

_opencode_vpn_ns_for() {
    # $1 = num -> namespace name (1 -> vpn, N -> vpnN).
    if [ "$1" -eq 1 ]; then echo vpn; else echo "vpn$1"; fi
}

_opencode_vpn_proton_for() {
    # $1 = num -> config name for 'vpn-netns up' (1 -> proton, N -> protonN).
    if [ "$1" -eq 1 ]; then echo proton; else echo "proton$1"; fi
}

_opencode_vpn_offer_up() {
    # $1 = num. If interactive, offer to bring the namespace up.
    local num="$1" ns proton ans
    ns="$(_opencode_vpn_ns_for "$num")"
    proton="$(_opencode_vpn_proton_for "$num")"
    if [ -t 0 ]; then
        printf "Namespace '%s' is not running. Bring it up now? [y/N] " "$ns"
        read -r ans || ans=""
        if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            sudo "$_OPENCODE_VPN_BIN" up "$proton" || return 1
            return 0
        fi
    fi
    echo "Error: Network namespace '${ns}' is not running."
    echo "Bring it up first with: sudo ${_OPENCODE_VPN_BIN} up ${proton}"
    return 1
}

  _opencode_vpn_launch() {
      # $1 = ns, rest = args passed verbatim to opencode inside the namespace.
      # Also accepts "desktop" as first arg after ns: wraps opencode-desktop
      # with the same VPN tunnel while preserving Wayland/X11 env.
      local ns="$1" bin age mode="cli" user_home
      shift
      bin="$(_opencode_vpn_resolve_opencode)" || {
          echo "Error: no opencode binary found (looked in ~/.opencode/bin, ~/.opencode, /usr/bin, PATH)" >&2
          return 1
      }
      if [[ "${1:-}" = "desktop" ]]; then mode="desktop"; shift; fi
      if [[ "$mode" = "desktop" ]]; then
          if command -v opencode-desktop &>/dev/null; then
              bin="$(command -v opencode-desktop)"
          else
              bin="opencode-desktop"
          fi
      fi
      age="$(_opencode_vpn_handshake_age "$ns")"
      if [ "$age" = "never" ] || { [[ "$age" =~ ^[0-9]+$ ]] && [ "$age" -gt "$_OPENCODE_VPN_STALE_AFTER" ]; }; then
          echo "Warning: no recent WireGuard handshake in '${ns}' (last: ${age}) — tunnel may be down." >&2
      fi
      user_home="${HOME:-$(eval echo "~${SUDO_USER:-$USER}")}"
      # session env with fallbacks (foot sometimes lacks WAYLAND_DISPLAY/DBUS)
      local xrd="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      local wld="${WAYLAND_DISPLAY:-}"
      [ -z "$wld" ] && [ -S "$xrd/wayland-1" ] && wld="wayland-1"
      local dbus="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$xrd/bus}"
      if [[ "$mode" = "desktop" ]]; then
          local wdir="${PWD}"
          [ -d "$wdir" ] || wdir="$user_home"
          sudo --preserve-env=DISPLAY,XAUTHORITY,SSH_AUTH_SOCK \
              ip netns exec "$ns" sudo -u "${SUDO_USER:-$USER}" \
              env XDG_RUNTIME_DIR="$xrd" WAYLAND_DISPLAY="$wld" DBUS_SESSION_BUS_ADDRESS="$dbus" \
              HOME="$user_home" \
              bash -c "cd $(printf '%q' "$wdir") && exec $(printf '%q' "$bin") $(printf '%q ' "$@") &"
          return 0
      fi
      # preserve key env so gh/ssh/git work inside netns (DBUS for keyring, SSH agent, etc.)
      sudo --preserve-env=SSH_AUTH_SOCK,GH_TOKEN,GITHUB_TOKEN \
          ip netns exec "$ns" sudo -u "${SUDO_USER:-$USER}" \
          env XDG_RUNTIME_DIR="$xrd" WAYLAND_DISPLAY="$wld" DBUS_SESSION_BUS_ADDRESS="$dbus" \
          HOME="$user_home" \
          bash -c "exec $(printf '%q' "$bin") $(printf '%q ' "$@")"
  }

  _opencode_vpn_menu() {
      # Picker for bare 'opencode-vpn [args...]'. Remaining args go to opencode.
      # If first arg is "desktop", strip it and forward everything to desktop launch.
      local detached_vpn="cli" nums n ns def direct choices pick ans bin
      if [[ "${1:-}" = "desktop" ]]; then
          detached_vpn="desktop"
          shift
      fi
      nums="$(_opencode_vpn_nums | tr '\n' ' ')"
    # default is always 1 if it exists (user asked), else first UP, else first num
    def=""
    if echo " $nums " | grep -q " 1 "; then
        def=1
    else
        for n in $nums; do
          ns="$(_opencode_vpn_ns_for "$n")"
          if [ -z "$def" ] && _opencode_vpn_ns_up "$ns"; then
              def="$n"
          fi
        done
    fi
    echo "VPN namespaces:"
    for n in $nums; do
        ns="$(_opencode_vpn_ns_for "$n")"
        printf '  %s) %-6s %s\n' "$n" "$ns" "$(_opencode_vpn_health "$ns")"
    done
    direct=1
    if [ -n "$nums" ]; then
        for direct in $nums; do :; done
        direct="$(( direct + 1 ))"
        [ -z "$def" ] && def="$(echo "$nums" | awk '{print $1}')"
    fi
    [ -z "$def" ] && def=1
    printf '  %s) no VPN — run opencode directly\n' "$direct"
    choices="$(echo "$nums" | tr ' ' '/')"
    [ -n "$nums" ] && choices="${choices}/"
    choices="${choices}${direct}"
    pick=""
    if [ -t 0 ]; then
        printf 'Pick [%s] (default %s): ' "$choices" "$def"
        read -r pick || pick=""
    else
        # Non-interactive: honour a piped choice if present, else default.
        read -t 1 -r pick 2>/dev/null || pick=""
    fi
    [ -z "$pick" ] && pick="$def"
    if [ "$pick" = "$direct" ]; then
        bin="$(_opencode_vpn_resolve_opencode)" || {
            echo "Error: no opencode binary found (looked in ~/.opencode/bin, ~/.opencode, /usr/bin, PATH)" >&2
            return 1
        }
        exec "$bin" "$@"
    fi
    if ! [[ "$pick" =~ ^[1-9][0-9]*$ ]] || ! echo " $nums " | grep -q " $pick "; then
        echo "Error: invalid choice '$pick' (expected one of: $(echo "$choices" | tr '/' ' '))"
        return 1
    fi
      ns="$(_opencode_vpn_ns_for "$pick")"
      if ! _opencode_vpn_ns_up "$ns"; then
          if [ -t 0 ]; then
              printf "Namespace '%s' is DOWN. Bring it up now? [y/N] " "$ns"
              read -r ans || ans=""
              if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                  sudo "$_OPENCODE_VPN_BIN" up "$(_opencode_vpn_proton_for "$pick")" || return 1
              else
                  echo "Aborted."
                  return 1
              fi
          else
              echo "Error: namespace '${ns}' is not running."
              echo "Bring it up with: sudo ${_OPENCODE_VPN_BIN} up $(_opencode_vpn_proton_for "$pick")"
              return 1
          fi
      fi
      if [[ "$detached_vpn" = "desktop" ]]; then
          _opencode_vpn_launch "$ns" desktop "$@"
      else
          _opencode_vpn_launch "$ns" "$@"
      fi
  }

opencode-vpn() {
    local first="${1:-}" num ns
    case "$first" in
        status)
            local s_n s_ns s_nums
            s_nums="$(_opencode_vpn_nums)"
            if [ -z "$s_nums" ]; then
                echo "No ~/.wireguard/proton*.conf found."
                return 1
            fi
            for s_n in $s_nums; do
                s_ns="$(_opencode_vpn_ns_for "$s_n")"
                printf '%-6s %s\n' "$s_ns" "$(_opencode_vpn_health "$s_ns")"
            done
            return 0
            ;;
        -h|--help|help)
  echo "Usage:"
          echo "  opencode-vpn N [args...]  Run opencode inside namespace 'vpn[N]' (~/.wireguard/proton[N].conf)"
          echo "  opencode-vpn status       Show tunnel health (no password needed)"
          echo "  opencode-vpn [args...]    Interactive picker, then run with args"
          echo "  opencode-vpn desktop [args...]  Same but for the Electron desktop app (keeps Wayland)"
            echo "Manage tunnels with: sudo ${_OPENCODE_VPN_BIN} {up|down|restart|status} proton|proton2|..."
            return 0
            ;;
        *)
            if [[ "$first" =~ ^[0-9]+$ ]]; then
                if ! [[ "$first" =~ ^[1-9][0-9]*$ ]]; then
                    echo "Error: VPN number must be 1 or higher."
                    return 1
                fi
                num="$first"
                shift
                ns="$(_opencode_vpn_ns_for "$num")"
                if ! _opencode_vpn_ns_up "$ns"; then
                    _opencode_vpn_offer_up "$num" || return 1
                fi
                _opencode_vpn_launch "$ns" "$@"
                return $?
            fi
            _opencode_vpn_menu "$@"
            return $?
            ;;
    esac
}

# Convenience alias for tunnel management (prompts for password unless sudoers allows it)
alias vpn-netns="sudo $HOME/.local/bin/vpn-netns"

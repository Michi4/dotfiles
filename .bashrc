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

# Reuse running ssh-agent or start a new one
export SSH_ENV="$HOME/.ssh/agent-environment"
export STABLE_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
}

# Prefer the stable systemd socket when it answers (rc 0 = has keys,
# rc 1 = alive but empty); else per-shell fallback.
STABLE_RC=2
if [ -S "$STABLE_SOCK" ]; then
  SSH_AUTH_SOCK="$STABLE_SOCK" ssh-add -l >/dev/null 2>&1
  STABLE_RC=$?
fi
if [ "$STABLE_RC" = 0 ] || [ "$STABLE_RC" = 1 ]; then
    export SSH_AUTH_SOCK="$STABLE_SOCK"
    # top up keys silently - stdin closed so this can NEVER prompt
    ssh-add -q ~/.ssh/id_ed25519 ~/.ssh/bwh < /dev/null 2>/dev/null || true
elif [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent
    }
else
    start_agent
fi

export MOZ_ENABLE_WAYLAND=1
export THUNDERBIRD_WAYLAND=1
alias reset-dock='sudo sh -c "echo -n \"usb2\" > /sys/bus/usb/drivers/usb/unbind && sleep 1 && echo -n \"usb2\" > /sys/bus/usb/drivers/usb/bind"'

# Fix Lenovo dock USB (Renesas controller) after using with Windows — no reboot needed
alias fixdock='sudo /usr/local/bin/renesas-usb-fix.sh'
# opencode-vpn — run opencode inside a WireGuard network namespace.
# Numbers map to exit confs in order (proton first, then oracle):
#   home:   1=proton(vpn) 2=proton2(vpn2) 3=oraclefrankfurt(vpn-frankfurt) 4=oraclemumbai(vpn-mumbai)
#   laptop: 1..3=proton..proton3, 4=oraclefrankfurt, 5=oraclemumbai
# Names also work: frankfurt/fra, mumbai/mum, oraclefrankfurt, oraclemumbai.
#   opencode-vpn 3 [args...]        -> run opencode in vpn-frankfurt (on home)
#   opencode-vpn frankfurt [args...]-> same via name
#   opencode-vpn desktop [N|name]   -> launch opencode desktop in namespace
#   opencode-desktop-vpn [N|name]   -> same (desktop wrapper)
#   opencode-vpn status             -> tunnel health table (no password needed)
#   opencode-vpn [args...]          -> interactive picker, then run with args
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

_opencode_vpn_resolve_desktop() {
    local c
    # NOTE: must be a regular file — /usr/lib/opencode-desktop is a directory (app.asar).
    c="$(command -v opencode-desktop 2>/dev/null || true)"
    if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then
        echo "$c"
        return 0
    fi
    for c in /usr/bin/opencode-desktop /usr/local/bin/opencode-desktop "$HOME/.local/bin/opencode-desktop"; do
        if [ -f "$c" ] && [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    done
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

# (Tip: check a tunnel's public exit IP on demand with:
#   sudo ip netns exec <ns> curl -s --max-time 5 https://api.ipify.org)

_opencode_vpn_health() {
    # $1 = namespace -> one-line health summary (fast: no egress probe here,
    # providers rate-limit shared exits and each probe can stall for seconds).
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

_opencode_vpn_confs() {
    # Ordered exit-confs: proton.conf, proton2..N (numeric), then oraclefrankfurt, oraclemumbai.
    # Prints basenames without .conf, one per line. (wg-cluster/home/bwh are infra, never listed.)
    local f n
    [ -f "$HOME/.wireguard/proton.conf" ] && echo proton
    for f in "$HOME"/.wireguard/proton[0-9]*.conf; do
        [ -e "$f" ] || continue
        n="${f##*/proton}"
        n="${n%.conf}"
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" != "1" ] && echo "proton$n"
    done | sort -t n -k2 -n -u
    [ -f "$HOME/.wireguard/oraclefrankfurt.conf" ] && echo oraclefrankfurt
    [ -f "$HOME/.wireguard/oraclemumbai.conf" ] && echo oraclemumbai
}

_opencode_vpn_nums() {
    # VPN numbers available on this host (1..N over _opencode_vpn_confs).
    _opencode_vpn_confs | nl -v1 -w1 | awk '{print $1}'
}

_opencode_vpn_conf_for() {
    # $1 = num -> conf basename.
    _opencode_vpn_confs | sed -n "${1}p"
}

_opencode_vpn_ns_for() {
    # $1 = num -> namespace name (proton->vpn, protonN->vpnN, oracle*->vpn-*)
    local conf
    conf="$(_opencode_vpn_conf_for "$1")"
    case "$conf" in
        proton) echo vpn ;;
        proton*) echo "vpn${conf#proton}" ;;
        oraclefrankfurt) echo vpn-frankfurt ;;
        oraclemumbai) echo vpn-mumbai ;;
        ""|" "*) echo "" ;;
        *) echo "vpn-${conf}" ;;
    esac
}

_opencode_vpn_num_for_name() {
    # $1 = name (number, conf, alias, namespace) -> number. Prints "" if unknown.
    local name="$1" i conf
    if [[ "$name" =~ ^[0-9]+$ ]]; then
        if [ -n "$(_opencode_vpn_conf_for "$name")" ]; then echo "$name"; fi
        return 0
    fi
    case "$name" in
        frankfurt|fra|vpn-frankfurt|vpn-fra) name="oraclefrankfurt" ;;
        mumbai|mum|vpn-mumbai|vpn-mum) name="oraclemumbai" ;;
        vpn) name="proton" ;;
        vpn[0-9]*) name="proton${name#vpn}" ;;
    esac
    i=0
    while IFS= read -r conf; do
        i=$(( i + 1 ))
        if [ "$conf" = "$name" ]; then echo "$i"; return 0; fi
    done < <(_opencode_vpn_confs)
    echo ""
}

_opencode_vpn_offer_up() {
    # $1 = num. If interactive, offer to bring the namespace up.
    local num="$1" ns conf ans
    ns="$(_opencode_vpn_ns_for "$num")"
    conf="$(_opencode_vpn_conf_for "$num")"
    if [ -t 0 ]; then
        printf "Namespace '%s' is not running. Bring it up now? [y/N] " "$ns"
        read -r ans || ans=""
        if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            sudo "$_OPENCODE_VPN_BIN" up "$conf" || return 1
            return 0
        fi
    fi
    echo "Error: Network namespace '${ns}' is not running."
    echo "Bring it up first with: sudo ${_OPENCODE_VPN_BIN} up ${conf}"
    return 1
}

_opencode_vpn_launch() {
    # $1 = ns, rest = args passed verbatim to opencode inside the namespace.
    local ns="$1" bin age
    shift
    bin="$(_opencode_vpn_resolve_opencode)" || {
        echo "Error: no opencode binary found (looked in ~/.opencode/bin, ~/.opencode, /usr/bin, PATH)" >&2
        return 1
    }
    age="$(_opencode_vpn_handshake_age "$ns")"
    if [ "$age" = "never" ] || { [[ "$age" =~ ^[0-9]+$ ]] && [ "$age" -gt "$_OPENCODE_VPN_STALE_AFTER" ]; }; then
        echo "Warning: no recent WireGuard handshake in '${ns}' (last: ${age}) — tunnel may be down." >&2
    fi
    sudo ip netns exec "$ns" su - "${SUDO_USER:-$USER}" -c "${bin} $(printf '%q ' "$@")"
}

_opencode_vpn_launch_desktop() {
    # $1 = ns. Launch opencode desktop GUI with network inside the namespace.
    # Filesystem is shared (only net is isolated), so Wayland/X sockets stay visible.
    local ns="$1" bin age user
    bin="$(_opencode_vpn_resolve_desktop)" || {
        echo "Error: no opencode-desktop binary found (looked in /usr/lib/opencode-desktop, PATH)" >&2
        return 1
    }
    age="$(_opencode_vpn_handshake_age "$ns")"
    if [ "$age" = "never" ] || { [[ "$age" =~ ^[0-9]+$ ]] && [ "$age" -gt "$_OPENCODE_VPN_STALE_AFTER" ]; }; then
        echo "Warning: no recent WireGuard handshake in '${ns}' (last: ${age}) — tunnel may be down." >&2
    fi
    user="${SUDO_USER:-$USER}"
    echo "Launching opencode-desktop in namespace '${ns}' as ${user}..."
    # Keep GUI env for Wayland/X/dbus; run detached so the terminal stays usable.
    # (Only the network is isolated — the Wayland/dbus sockets stay reachable.)
    sudo ip netns exec "$ns" su - "$user" -c "env WAYLAND_DISPLAY='${WAYLAND_DISPLAY:-}' DISPLAY='${DISPLAY:-}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR:-}' DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS:-}' '${bin}'" &
    echo "Desktop starting (PID $!). Check exit IP with: sudo ip netns exec ${ns} curl -s --max-time 5 https://api.ipify.org"
}

_opencode_vpn_menu() {
    # Picker for bare 'opencode-vpn [args...]'. Remaining args go to opencode.
    # If first remaining arg is 'desktop', launch the desktop GUI instead.
    local nums n ns conf def direct choices pick ans bin first
    first="${1:-}"
    if [ "$first" = "desktop" ]; then
        shift
        _opencode_vpn_menu_desktop "$@"
        return $?
    fi
    nums="$(_opencode_vpn_nums | tr '\n' ' ')"
    def=""
    echo "VPN namespaces:"
    for n in $nums; do
        ns="$(_opencode_vpn_ns_for "$n")"
        conf="$(_opencode_vpn_conf_for "$n")"
        printf '  %s) %-13s %-16s %s\n' "$n" "$ns" "($conf)" "$(_opencode_vpn_health "$ns")"
        if [ -z "$def" ] && _opencode_vpn_ns_up "$ns"; then
            def="$n"
        fi
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
    # allow names in the picker too
    if ! [[ "$pick" =~ ^[0-9]+$ ]]; then
        pick="$(_opencode_vpn_num_for_name "$pick")"
    fi
    if ! [[ "$pick" =~ ^[1-9][0-9]*$ ]] || [ -z "$(_opencode_vpn_conf_for "$pick")" ]; then
        echo "Error: invalid choice (expected one of: $(echo "$choices" | tr '/' ' ') or frankfurt/mumbai)"
        return 1
    fi
    ns="$(_opencode_vpn_ns_for "$pick")"
    if ! _opencode_vpn_ns_up "$ns"; then
        if [ -t 0 ]; then
            printf "Namespace '%s' is DOWN. Bring it up now? [y/N] " "$ns"
            read -r ans || ans=""
            if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                sudo "$_OPENCODE_VPN_BIN" up "$(_opencode_vpn_conf_for "$pick")" || return 1
            else
                echo "Aborted."
                return 1
            fi
        else
            echo "Error: namespace '${ns}' is not running."
            echo "Bring it up with: sudo ${_OPENCODE_VPN_BIN} up $(_opencode_vpn_conf_for "$pick")"
            return 1
        fi
    fi
    if [ "${1:-}" = "desktop" ]; then
        shift
        _opencode_vpn_launch_desktop "$ns"
        return $?
    fi
    _opencode_vpn_launch "$ns" "$@"
}

_opencode_vpn_menu_desktop() {
    # Picker that launches opencode-desktop in the chosen namespace.
    local nums n ns conf def direct choices pick ans
    nums="$(_opencode_vpn_nums | tr '\n' ' ')"
    def=""
    echo "VPN namespaces (desktop):"
    for n in $nums; do
        ns="$(_opencode_vpn_ns_for "$n")"
        conf="$(_opencode_vpn_conf_for "$n")"
        printf '  %s) %-13s %-16s %s\n' "$n" "$ns" "($conf)" "$(_opencode_vpn_health "$ns")"
        if [ -z "$def" ] && _opencode_vpn_ns_up "$ns"; then
            def="$n"
        fi
    done
    [ -z "$def" ] && def="$(echo "$nums" | awk '{print $1}')"
    [ -z "$def" ] && def=1
    choices="$(echo "$nums" | tr ' ' '/')"
    pick=""
    if [ -t 0 ]; then
        printf 'Desktop VPN [%s] (default %s): ' "$choices" "$def"
        read -r pick || pick=""
    else
        read -t 1 -r pick 2>/dev/null || pick=""
    fi
    [ -z "$pick" ] && pick="$def"
    if ! [[ "$pick" =~ ^[0-9]+$ ]]; then
        pick="$(_opencode_vpn_num_for_name "$pick")"
    fi
    if [ -z "$pick" ] || [ -z "$(_opencode_vpn_conf_for "$pick")" ]; then
        echo "Error: invalid choice (expected one of: $(echo "$choices" | tr '/' ' ') or frankfurt/mumbai)"
        return 1
    fi
    ns="$(_opencode_vpn_ns_for "$pick")"
    if ! _opencode_vpn_ns_up "$ns"; then
        if [ -t 0 ]; then
            printf "Namespace '%s' is DOWN. Bring it up now? [y/N] " "$ns"
            read -r ans || ans=""
            if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                sudo "$_OPENCODE_VPN_BIN" up "$(_opencode_vpn_conf_for "$pick")" || return 1
            else
                echo "Aborted."
                return 1
            fi
        else
            echo "Error: namespace '${ns}' is not running."
            return 1
        fi
    fi
    _opencode_vpn_launch_desktop "$ns"
}

opencode-vpn() {
    local first="${1:-}" num ns conf
    case "$first" in
        status)
            local s_n s_ns s_conf s_nums
            s_nums="$(_opencode_vpn_nums)"
            if [ -z "$s_nums" ]; then
                echo "No exit confs found (~/.wireguard/proton*.conf, oracle*.conf)."
                return 1
            fi
            for s_n in $s_nums; do
                s_ns="$(_opencode_vpn_ns_for "$s_n")"
                s_conf="$(_opencode_vpn_conf_for "$s_n")"
                printf '%-13s %-16s %s\n' "$s_ns" "($s_conf)" "$(_opencode_vpn_health "$s_ns")"
            done
            return 0
            ;;
        desktop)
            shift
            # opencode-vpn desktop [N|name]: desktop picker or direct
            if [ -n "${1:-}" ]; then
                num="$(_opencode_vpn_num_for_name "$1")"
                if [ -z "$num" ]; then
                    echo "Error: unknown VPN '$1' (try: $(_opencode_vpn_confs | tr '\n' ' '))"
                    return 1
                fi
                shift
                ns="$(_opencode_vpn_ns_for "$num")"
                if ! _opencode_vpn_ns_up "$ns"; then
                    _opencode_vpn_offer_up "$num" || return 1
                fi
                _opencode_vpn_launch_desktop "$ns"
                return $?
            fi
            _opencode_vpn_menu_desktop
            return $?
            ;;
        -h|--help|help)
            echo "Usage:"
            echo "  opencode-vpn N [args...]          Run opencode in namespace N (number, conf or alias)"
            echo "  opencode-vpn frankfurt [args...]  Shortcut for oraclefrankfurt (vpn-frankfurt)"
            echo "  opencode-vpn mumbai [args...]     Shortcut for oraclemumbai (vpn-mumbai)"
            echo "  opencode-vpn desktop [N|name]     Launch opencode desktop GUI in namespace"
            echo "  opencode-vpn status               Show tunnel health (no password needed)"
            echo "  opencode-vpn [args...]            Interactive picker, then run with args"
            echo "Manage tunnels with: sudo ${_OPENCODE_VPN_BIN} {up|down|restart|status} proton|proton2|oraclefrankfurt|oraclemumbai|..."
            return 0
            ;;
        *)
            if [[ "$first" =~ ^[0-9]+$ ]] || [ -n "$(_opencode_vpn_num_for_name "$first")" ]; then
                if [[ "$first" =~ ^[0-9]+$ ]]; then
                    num="$first"
                else
                    num="$(_opencode_vpn_num_for_name "$first")"
                fi
                if [ -z "$num" ] || [ -z "$(_opencode_vpn_conf_for "$num")" ]; then
                    echo "Error: unknown VPN '$first' (try: $(_opencode_vpn_confs | tr '\n' ' '))"
                    return 1
                fi
                shift
                # 'opencode-vpn N desktop' launches the GUI in N
                if [ "${1:-}" = "desktop" ]; then
                    ns="$(_opencode_vpn_ns_for "$num")"
                    if ! _opencode_vpn_ns_up "$ns"; then
                        _opencode_vpn_offer_up "$num" || return 1
                    fi
                    _opencode_vpn_launch_desktop "$ns"
                    return $?
                fi
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

opencode-desktop-vpn() {
    # Wrapper: opencode-desktop-vpn [N|name] — desktop GUI inside a VPN namespace.
    local num="${1:-}" ns
    if [ -z "$num" ]; then
        _opencode_vpn_menu_desktop
        return $?
    fi
    num="$(_opencode_vpn_num_for_name "$num")"
    if [ -z "$num" ]; then
        echo "Error: unknown VPN '$1' (try: $(_opencode_vpn_confs | tr '\n' ' '))"
        return 1
    fi
    ns="$(_opencode_vpn_ns_for "$num")"
    if ! _opencode_vpn_ns_up "$ns"; then
        _opencode_vpn_offer_up "$num" || return 1
    fi
    _opencode_vpn_launch_desktop "$ns"
}

# Convenience alias for tunnel management (prompts for password unless sudoers allows it)
alias vpn-netns="sudo $HOME/.local/bin/vpn-netns"

# opencode providers (tokenharbor/orcarouter)
[ -f "$HOME/.config/opencode/.env_providers" ] && source "$HOME/.config/opencode/.env_providers"

# personal scripts (laptop-backup, paste-redact, ...)
export PATH="$PATH:$HOME/bin"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

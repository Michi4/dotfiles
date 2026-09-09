#!/bin/bash
# dns-updown-split.sh - wrapper around OpenVPN's dns-updown (/usr/lib/openvpn).
# OpenVPN >= 2.7 calls its DNS handler natively (--dns-updown) with the pushed
# server env; when the server pushes no resolve-domains the stock handler
# assigns a catch-all (~.) + DefaultRoute, routing ALL DNS via the tunnel.
# This wrapper lets the stock handler run first, then narrows the tunnel link
# to apronix.net so public names use the global resolvers (split DNS).
# Runs as root (openvpn runs via sudo) - keep this file owner-writable only.
# Referenced from bwh.conf:  dns-updown /home/michi/.config/openvpn/dns-updown-split.sh
/usr/lib/openvpn/dns-updown "$@"
rc=$?
if [ "${script_type:-}" = "dns-up" ] && [ -n "${dev:-}" ]; then
    /usr/bin/resolvectl domain "$dev" apronix.net
    /usr/bin/resolvectl default-route "$dev" no
fi
exit $rc

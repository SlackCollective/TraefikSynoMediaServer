#!/bin/sh
# tun-gpu.sh — device setup needed at boot before the compose stack comes up:
#   - /dev/net/tun: required for WireGuard (gluetun's VPN tunnel; also host WireGuard, see
#     REINSTALL.md step 8) — DSM doesn't create this by default.
#   - /dev/dri: Plex hardware transcoding (Intel QuickSync) — DSM resets its permissions
#     on reboot, blocking the container's non-root PUID from using it.
#   - wireguard.ko: the host WireGuard package (used by login-bot's run.sh, see its wg1.conf)
#     is registered "non_installed" in DSM's package registry (broken/orphaned — files exist
#     on disk but DSM never auto-loads the module at boot for it). Load it directly here
#     instead of depending on that package's own startup path.
# Register as a DSM Task Scheduler "Triggered Task" (Event: Boot-up, User: root).
# Idempotent: safe to run any time. Deploy to /volume1/dev/tun-gpu.sh (see install.sh).

set -eu

# --- /dev/net/tun ---
if [ ! -c /dev/net/tun ]; then
    [ -d /dev/net ] || mkdir -m 755 /dev/net
    mknod /dev/net/tun c 10 200
    chmod 0755 /dev/net/tun
fi

if ! lsmod | grep -q '^tun\s'; then
    insmod /lib/modules/tun.ko
fi

# --- /dev/dri (Plex hardware transcoding) ---
if [ -e /dev/dri ]; then
    chmod 755 /dev/dri
    [ -e /dev/dri/renderD128 ] && chmod 666 /dev/dri/renderD128
fi

# --- wireguard.ko (host WireGuard package, orphaned registration — see note above) ---
WG_KO=/volume1/@appstore/WireGuard/wireguard/wireguard.ko
if [ -f "$WG_KO" ] && ! lsmod | grep -q '^wireguard\s'; then
    insmod "$WG_KO" || true
fi

echo "tun-gpu.sh: done"

#!/bin/sh
# install.sh — deploy the host-setup scripts to /volume1/dev and run the relinker once.
# Run as root on the NAS, from this directory:  sudo sh install.sh
set -eu

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST=/volume1/dev

mkdir -p "$DEST"
cp "$SRC_DIR/shell-aliases.sh"        "$DEST/shell-aliases.sh"
cp "$SRC_DIR/relink-tools.sh"         "$DEST/relink-tools.sh"
cp "$SRC_DIR/iptables.sh"             "$DEST/iptables.sh"
cp "$SRC_DIR/tun-gpu.sh"              "$DEST/tun-gpu.sh"
cp "$SRC_DIR/traefik-logrotate.sh"    "$DEST/traefik-logrotate.sh"
cp "$SRC_DIR/traefik-logrotate.conf"  "$DEST/traefik-logrotate.conf"
cp "$SRC_DIR/prunelogs.sh"            "$DEST/prunelogs.sh"

chmod a+rx "$DEST"
chmod a+r  "$DEST/shell-aliases.sh"
chmod +x   "$DEST/relink-tools.sh"
chmod +x   "$DEST/iptables.sh"
chmod +x   "$DEST/tun-gpu.sh"
chmod +x   "$DEST/traefik-logrotate.sh"
chmod a+r  "$DEST/traefik-logrotate.conf"
chmod +x   "$DEST/prunelogs.sh"

echo "Deployed shell-aliases.sh, relink-tools.sh, iptables.sh, tun-gpu.sh, traefik-logrotate.{sh,conf}, and prunelogs.sh to $DEST."
echo "Running relink-tools.sh and tun-gpu.sh once..."
"$DEST/relink-tools.sh"
"$DEST/tun-gpu.sh"

cat <<'MSG'

One-time: register the boot tasks so they re-run after reboots / DSM resets:

  Control Panel -> Task Scheduler -> Create -> Triggered Task -> User-defined script
    Event:   Boot-up
    User:    root
    Command: sh /volume1/dev/relink-tools.sh

  Control Panel -> Task Scheduler -> Create -> Triggered Task -> User-defined script
    Event:   Boot-up
    User:    root
    Command: sh /volume1/dev/iptables.sh

  Control Panel -> Task Scheduler -> Create -> Triggered Task -> User-defined script
    Event:   Boot-up
    User:    root
    Command: sh /volume1/dev/tun-gpu.sh

Also point the existing daily "Prunelogs" Task Scheduler task's command at:

    sh /volume1/dev/prunelogs.sh

(or create it fresh, Event: Daily, User: root, if it doesn't exist yet — it now also
covers Traefik log rotation, see host-setup/README.md)

To load the aliases in your current shell now:  . /volume1/dev/shell-aliases.sh
MSG

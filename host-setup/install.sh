#!/bin/sh
# install.sh — deploy the host-setup scripts to /volume1/dev and run the relinker once.
# Run as root on the NAS, from this directory:  sudo sh install.sh
set -eu

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST=/volume1/dev

mkdir -p "$DEST"
cp "$SRC_DIR/shell-aliases.sh" "$DEST/shell-aliases.sh"
cp "$SRC_DIR/relink-tools.sh"  "$DEST/relink-tools.sh"
cp "$SRC_DIR/iptables.sh"      "$DEST/iptables.sh"

chmod a+rx "$DEST"
chmod a+r  "$DEST/shell-aliases.sh"
chmod +x   "$DEST/relink-tools.sh"
chmod +x   "$DEST/iptables.sh"

echo "Deployed shell-aliases.sh, relink-tools.sh, and iptables.sh to $DEST."
echo "Running relink-tools.sh once..."
"$DEST/relink-tools.sh"

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

To load the aliases in your current shell now:  . /volume1/dev/shell-aliases.sh
MSG

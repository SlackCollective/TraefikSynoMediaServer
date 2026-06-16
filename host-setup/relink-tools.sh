#!/bin/sh
# relink-tools.sh — re-establish the /volume1-based Node/Claude toolchain after a reboot
# or DSM reset. Register as a DSM Task Scheduler "Triggered Task" (Event: Boot-up, User: root).
# Idempotent: safe to run any time.
#
# Why this exists: DSM periodically resets /root (and can reset user homes and /usr/local),
# wiping the symlinks and profile edits that make node/npm/claude resolve. The actual data
# lives on /volume1 (never wiped); this script re-creates the thin links that point at it.

set -eu

NVM_CURRENT=/volume1/dev/nvm/current
CLAUDE_BASE=/volume1/dev/claude
ALIASES=/volume1/dev/shell-aliases.sh

# 1. Shared tool binaries onto /usr/local/bin (already on every shell's default PATH,
#    so no .profile/NVM_DIR is required for node/npm/claude to resolve).
for b in node npm npx claude; do
    ln -sfn "$NVM_CURRENT/bin/$b" "/usr/local/bin/$b"
done

# 2. Per-user Claude data symlinks (config + native-binary cache live on /volume1).
#    $1 = account name, $2 = home directory
link_claude_data() {
    _user=$1
    _home=$2
    [ -d "$_home" ] || return 0
    mkdir -p "$_home/.local/share" "$CLAUDE_BASE/$_user/share" "$CLAUDE_BASE/$_user/config"
    ln -sfn "$CLAUDE_BASE/$_user/share"  "$_home/.local/share/claude"
    ln -sfn "$CLAUDE_BASE/$_user/config" "$_home/.claude"
}
link_claude_data root /root
link_claude_data JacquesRousseau /var/services/homes/JacquesRousseau

# 3. Re-attach shared aliases to each account's rc files (survives /root + home resets).
SRC="[ -f $ALIASES ] && . $ALIASES"
for f in /root/.profile /root/.bashrc \
         /var/services/homes/JacquesRousseau/.profile \
         /var/services/homes/JacquesRousseau/.bashrc; do
    [ -f "$f" ] && ! grep -qF "$ALIASES" "$f" && printf '%s\n' "$SRC" >> "$f"
done

# 4. Keep the shared toolchain world-readable/executable (root manages, both users run).
chmod -R a+rX /volume1/dev/nvm 2>/dev/null || true

echo "relink-tools.sh: done"

#!/bin/sh
# relink-tools.sh — re-establish the /volume1-based Node toolchain and per-user Claude links
# after a reboot or DSM reset. Register as a DSM Task Scheduler "Triggered Task"
# (Event: Boot-up, User: root). Idempotent: safe to run any time.
#
# Why this exists: DSM periodically resets /root (and can reset user homes and /usr/local),
# wiping the symlinks and profile edits that make node/npm resolve and that point each user's
# native Claude install at /volume1. The actual data lives on /volume1 (never wiped); this
# script re-creates the thin links that point at it.

set -eu

NVM_CURRENT=/volume1/dev/nvm/current
CLAUDE_BASE=/volume1/dev/claude
ALIASES=/volume1/dev/shell-aliases.sh

# 1. Shared tool binaries onto /usr/local/bin (already on every shell's default PATH,
#    so no .profile/NVM_DIR is required for node/npm to resolve).
#    NOTE: claude is intentionally NOT shared here — it is a per-user *native* install
#    (~/.local/bin/claude). Remove any stale shared symlink so the native one wins on PATH.
for b in node npm npx; do
    ln -sfn "$NVM_CURRENT/bin/$b" "/usr/local/bin/$b"
done
rm -f /usr/local/bin/claude

# 2. Redirect ROOT's Claude data onto /volume1. root's home (/root) is on the small
#    system partition, so the native-binary cache must not live there.
#    IMPORTANT: accounts whose home is already on /volume1 (e.g. /var/services/homes/*)
#    need NO redirect — their native install lives on /volume1 naturally, and a symlink
#    here would *shadow* it and make `claude` report its binary "missing or broken".
link_claude_data() {
    _user=$1
    _home=$2
    [ -d "$_home" ] || return 0
    mkdir -p "$_home/.local/share" "$CLAUDE_BASE/$_user/share" "$CLAUDE_BASE/$_user/config"
    ln -sfn "$CLAUDE_BASE/$_user/share"  "$_home/.local/share/claude"
    ln -sfn "$CLAUDE_BASE/$_user/config" "$_home/.claude"
}
link_claude_data root /root
# NOTE: JacquesRousseau's home is on /volume1, so no redirect — do NOT add it here.

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

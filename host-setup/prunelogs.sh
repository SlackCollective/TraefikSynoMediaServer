#!/bin/sh
# prunelogs.sh — daily log maintenance, run as the "Prunelogs" DSM Task Scheduler task
# (Event: Daily ~02:45, User: root). Deploy to /volume1/dev/prunelogs.sh (see install.sh).
#
# Two unrelated jobs sharing one daily trigger for convenience:
#   1. Prune old script logs under /volume1/data/scripts/logs/*/, keeping the 2 most recent
#      per subdirectory.
#   2. Rotate Traefik's access.log/traefik.log (see traefik-logrotate.sh/.conf for why this
#      exists instead of relying on DSM's own logrotate).
# Chained with `;`, not `&&` — a failure in one must not block the other.

for dir in /volume1/data/scripts/logs/*/; do
    [ "$(basename "$dir")" = "@eaDir" ] && continue
    ls -1t "$dir" | tail -n +3 | while IFS= read -r entry; do
        rm -rf -- "$dir$entry"
    done
done

sh /volume1/dev/traefik-logrotate.sh || true

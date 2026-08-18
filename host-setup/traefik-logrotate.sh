#!/bin/sh
# traefik-logrotate.sh — rotates Traefik's access.log/traefik.log using the config and state
# file on /volume1 (not /etc/logrotate.d — see traefik-logrotate.conf for why).
# Register as a DSM Task Scheduler daily task, user root. Idempotent: safe to run any time.
# Deploy to /volume1/dev/traefik-logrotate.sh (see install.sh).

set -eu

/usr/bin/logrotate --state /volume1/dev/traefik-logrotate.state -f /volume1/dev/traefik-logrotate.conf

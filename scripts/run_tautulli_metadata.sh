#!/bin/sh
# run_tautulli_metadata.sh — load credentials from scripts/.env (not committed,
# create it from .env.example) and run tautulli_metadata.py.
set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"

set -a
. "$DIR/.env"
set +a

exec python3 "$DIR/tautulli_metadata.py"

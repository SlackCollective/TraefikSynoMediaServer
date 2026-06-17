# scripts

Maintenance utilities for the media stack that aren't part of `docker compose` itself.

## tautulli_metadata.py

Re-matches Tautulli's history/watch-stats to current Plex rating keys after a library
move or re-scan, then clears the "recently added" table. From
[/u/SwiftPanda16](https://www.reddit.com/r/PleX/).

Setup:

```sh
cp scripts/.env.example scripts/.env   # then fill in real values, chmod 600
./run_tautulli_metadata.sh             # defaults to DRY_RUN=true — review output first
DRY_RUN=false ./run_tautulli_metadata.sh  # actually writes to the Tautulli database
```

`PLEX_URL` must be the NAS's LAN IP (e.g. `http://192.168.1.156:32400`), not
`localhost`/`127.0.0.1` — this host's `route_localnet` sysctl is 0, so loopback
connections to Docker's published ports are dropped as martian packets before they
reach the container.

`scripts/.env` holds live credentials and is gitignored (matches the repo's `.env`
pattern) — never commit it.

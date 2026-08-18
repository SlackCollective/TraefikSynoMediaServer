# Synology NAS — Reinstall Runbook

Steps to rebuild this NAS from a fresh DSM install. Companion to the rest of `host-setup/`:
`README.md` (Node/Claude toolchain), `shell-aliases.sh`, `relink-tools.sh`, `iptables.sh`,
`install.sh`, and `TRIP-CHECKLIST.md`.

> Corrections and caveats vs. the original notes are flagged inline with **⚠**.

## 1. DSM base

1. Reinstall DSM.
2. Reset `/volume1` to default Linux permissions (File Station / Control Panel).
3. Update packages; do basic setup.
4. Install **Container Manager**, a **text editor**, and **Hyper Backup**.

## 2. Community packages

From SynoCommunity (`https://packages.synocommunity.com/`):

- Syno CLI Video Drivers
- Syno CLI File Tools

## 3. DSM ports & security

- Change DSM HTTP/HTTPS off the default ports (5000 / 5001).
- Enable "redirect HTTP to HTTPS".

## 4. Docker user, group & folder permissions

- Create the `docker` **group**, with R/W on the `data` and `docker` shared folders.
- Create the `docker` **user**.
- Add your admin user (`JacquesRousseau`) to the `docker` group.
- Remove **Everyone** from Read permissions on the `docker` shared folder.
- Via CLI, note the **PUID** and **PGID** of the `docker` user, and the GID of the Syno
  **video** group (used for Plex hardware transcoding).

> ⚠ Original said "PUID and GUID" and "Sino videogroup" — corrected to **PGID** and **Syno
> video group**. The original also listed "create docker user/group" three times; consolidated.

## 5. Shell aliases

The maintained alias set now lives in **`host-setup/shell-aliases.sh`**, deployed to
`/volume1/dev/shell-aliases.sh` and sourced from each account's `~/.profile` and `~/.bashrc`
(re-attached after DSM resets by `relink-tools.sh`). Prefer that mechanism over hand-editing
skeleton files.

> ⚠ The original edited `/etc.defaults/.bashrc_profile`. That filename is **not** read by ash
> (login shell, reads `~/.profile`) or bash (reads `~/.bashrc`/`~/.profile`), so it likely had
> no effect — use the `shell-aliases.sh` mechanism instead.

Reference list (corrected):

```sh
alias cdkr='cd /volume1/docker/apps'
alias list='docker ps -a'
alias down='sudo docker compose down -v'       # ⚠ -v also removes volumes
alias pull='sudo docker compose pull'
alias up='sudo docker compose up -d'
alias inspect='sudo docker inspect'
alias stop='sudo docker stop'
alias start='sudo docker start'
alias prune='sudo docker system prune'
alias users='sudo chown -R docker:docker /volume1/data /volume1/docker/apps'
alias perms='sudo chmod -R a=,a+rX,u+w,g+w /volume1/data /volume1/docker/apps'
logs() { docker logs -tf --tail=50 "$@"; }     # function, not alias
```

> ⚠ Two fixes vs. the original: `perms` was missing the leading `/` on `/volume1/docker/apps`;
> and `logs` was written as an alias using `"$@"` (which an alias can't consume) and without the
> `alias` keyword — it must be a shell **function** to take a container argument.

## 6. Docker socket & folder ownership

```sh
sudo chown root:docker /run/docker.sock
sudo chmod 0660 /run/docker.sock
```

- `chown`/`chmod` the `data` and `docker` folders to `docker:docker` (the `users` / `perms`
  aliases above).

> ⚠ The compose stack reaches Docker through the **socket-proxy** containers
> (`socket-proxy-ro` / `socket-proxy-rw`), not the raw socket — these socket perms are only for
> CLI `docker` use by the `docker` group. Verify they're still needed.

## 7. TLS / sensitive-file permissions

- `chmod 600` Traefik's `acme.json` (ACME cert store — Traefik refuses to start otherwise).
- Make Organizr's `logrotate` config **not** world-readable.

## 8. VPN — host WireGuard + Tailscale (optional)

> ⚠ Optional: Tailscale (below) already provides remote access for the iPad/laptop from abroad.
> Host WireGuard is a separate, older mechanism — skip it unless something specific still
> depends on it. Note that gluetun's VPN tunnel (qBittorrent) does not depend on this either
> way; it only needs `/dev/net/tun`, set up in step 9.

- WireGuard SPK from blackvoid.club
  (`https://www.blackvoid.club/wireguard-spk-for-your-synology-nas/`). Follow the install
  instructions; **reboot before running the start script**, then:

```sh
# as root, after reboot:
/var/packages/WireGuard/scripts/start
```

> ⚠ On the current NAS, this package shows as **`non_installed`** in DSM's package registry
> (`synopkg status WireGuard`) even though its files are present at
> `/volume1/@appstore/WireGuard/wireguard/` — `/var/packages/WireGuard/scripts/start` no longer
> exists, so the package's own module-loading path is broken/orphaned. `tun-gpu.sh` (step 9)
> now loads `wireguard.ko` directly, bypassing this package's startup mechanism entirely. If
> reinstalling from scratch, try the SPK install as documented first — this bypass may not be
> needed on a clean install — but if the package again ends up in this state, `tun-gpu.sh`'s
> approach still works regardless of package registration.

- Install **Tailscale** (Package Center / SynoCommunity) for remote access — this is what the
  iPad/laptop use from abroad. See `TRIP-CHECKLIST.md`.

> ⚠ With Tailscale providing remote access, confirm whether the host WireGuard package is still
> needed or is legacy.

## 9. TUN / GPU / WireGuard module

Deploy and run **`host-setup/tun-gpu.sh`** — creates `/dev/net/tun` (+ loads the `tun` kernel
module) for gluetun's VPN tunnel, fixes `/dev/dri` permissions for Plex hardware transcoding,
and loads `wireguard.ko` for the host WireGuard tunnel (see step 8's ⚠ note — this bypasses
that package's own, currently-broken startup mechanism):

```sh
sh /volume1/dev/tun-gpu.sh
```

(Deployed automatically by `host-setup/install.sh` — see step 10 below. Also registered as a
Boot-up task in step 12, since DSM doesn't persist either fixup across reboots.)

> ⚠ Original said "TUNGPU and VPN commands", which was vague and undocumented. Resolved: this
> is `tun-gpu.sh`, now checked into `host-setup/`. The "VPN commands" turned out to be the same
> `/dev/net/tun` setup, not a separate script.

## 10. Node / Claude toolchain, Entware

Rebuild per `host-setup/README.md` → **"Rebuilding the toolchain from scratch"** (nvm + Node on
`/volume1/dev`, per-user **native** Claude Code), then deploy the host-setup scripts:

```sh
sudo sh host-setup/install.sh
```

Also (re)install **Entware** — DSM has no persistent `/opt` of its own, so this needs
redoing on a fresh NAS:

```sh
sudo sh -c '
mkdir -p /volume1/dev/entware
ln -sfn /volume1/dev/entware /opt
wget -O - https://bin.entware.net/x64-k3.2/installer/generic.sh | sh
'
sudo sh /volume1/dev/relink-tools.sh   # symlinks /opt/bin/* onto /usr/local/bin
```

Install packages as needed, e.g. `opkg install nano`. See `README.md` → Entware section.

> Added step — not in the original notes, but required to restore the Node/Claude environment
> on a fresh NAS.

## 11. Bring up the stack

- Pre-create the external Docker networks, then `docker compose up -d` (see repo `CLAUDE.md`).
- Configure **Hyper Backup**.

## 12. Task Scheduler — boot tasks

Register as **Triggered Tasks → Boot-up**, user **root**:

- `sh /volume1/dev/relink-tools.sh` — re-creates the toolchain symlinks (node/npm/npx, `wg`/
  `wg-quick`, Entware's `/opt` + its `/usr/local/bin` links, root's Claude data) after DSM
  resets.
- `sh /volume1/dev/iptables.sh` — host iptables NAT fixup so locally-originated connections to a
  published Docker port get hairpinned to the container (real client IP). See `README.md`.
- `sh /volume1/dev/tun-gpu.sh` — GPU + VPN device fixup: recreates `/dev/net/tun` (+ loads the
  `tun` kernel module, needed for gluetun's WireGuard tunnel powering qBittorrent's VPN),
  resets `/dev/dri` permissions (Plex hardware transcoding), and loads `wireguard.ko` for the
  host WireGuard tunnel (bypassing that package's broken registration, see step 8). None of
  the three survive a DSM reboot on their own. See `README.md`.

Also register (or update) one **daily** (not Boot-up) task, user **root**, named e.g.
"Prunelogs":

- `sh /volume1/dev/prunelogs.sh` — prunes old files under `/volume1/data/scripts/logs/*/`
  **and** rotates `traefik/logs/access.log` / `traefik.log` (compress + signal Traefik with
  `USR1` to reopen the file — Traefik has no rotation of its own). The Traefik piece exists
  because DSM's own `/etc/logrotate.d`-driven rotation for that log silently stopped at some
  point (evidenced by `access.log` growing past 1.6 GB unrotated), and its trigger mechanism
  on this DSM couldn't be confirmed — so this bypasses it entirely and lives self-contained
  on `/volume1/dev/` like everything else here. See `README.md`.

# host-setup

Host-level setup for the Synology NAS that is **not** part of the Traefik media stack:
a relocated Node/Claude Code toolchain on `/volume1`, shared shell aliases, an iptables
boot fixup for Docker's published ports, and boot tasks that make the whole thing
self-healing across reboots and DSM resets.

## Why

The DSM system partition (`/dev/md0`, mounted at `/`) is a fixed ~2.3 GB and fills up
(blocking DSM updates). Node + Claude Code's binaries and caches were living under `/root`
(~640 MB). This setup moves them to `/volume1` (TBs free) and exposes them so both **root**
and **JacquesRousseau** can run them.

DSM also periodically resets `/root` (and can reset user homes / `/usr/local`), wiping
symlinks and `.profile` edits. The data on `/volume1` survives; `relink-tools.sh` re-creates
the thin links that point at it.

## Layout on the NAS

```
/volume1/dev/
├── nvm/                      # relocated nvm + Node (NVM_DIR); `current` -> active version
│   └── current/bin/{node,npm,npx}
├── claude/
│   ├── root/{share,config}           # root's Claude data (native-binary cache + config)
│   └── JacquesRousseau/{share,config}# per-user; separate credentials/state
├── shell-aliases.sh          # this repo's copy, deployed here (chmod a+r)
├── relink-tools.sh           # this repo's copy, deployed here (chmod +x)
└── iptables.sh               # this repo's copy, deployed here (chmod +x)
```

**node/npm/npx** are exposed via `/usr/local/bin` symlinks (that dir is already on every
shell's default PATH), so **no `.profile` / `NVM_DIR` is required** to run them.

**claude is NOT shared this way.** Claude Code is a per-user **native** install at
`~/.local/bin/claude` (it self-migrates from npm-global to native and self-updates). The
`~/.local/share/claude` cache is symlinked to `/volume1/dev/claude/<user>` to keep it off
the system partition. `relink-tools.sh` removes any stale shared `/usr/local/bin/claude`
so the native one always wins on PATH.

## Deploy

From this directory on the NAS (as root), run the installer — it copies the scripts to
`/volume1/dev/`, sets permissions, and runs the relinker once:

```sh
sudo sh install.sh
```

<details>
<summary>…or do it by hand</summary>

```sh
cp shell-aliases.sh /volume1/dev/shell-aliases.sh
cp relink-tools.sh  /volume1/dev/relink-tools.sh
cp iptables.sh      /volume1/dev/iptables.sh
chmod a+rx /volume1/dev
chmod a+r  /volume1/dev/shell-aliases.sh
chmod +x   /volume1/dev/relink-tools.sh
chmod +x   /volume1/dev/iptables.sh
/volume1/dev/relink-tools.sh         # run once now
```
</details>

Then register the boot tasks so they re-run after every reboot / reset (the installer also
prints these steps). Both are **Control Panel → Task Scheduler → Create → Triggered Task →
User-defined script**, Event **Boot-up**, User **root**:
- `sh /volume1/dev/relink-tools.sh`
- `sh /volume1/dev/iptables.sh`

### iptables.sh

Waits (up to 2.5 min) for Docker's `DOCKER-USER` chain to appear at boot, then ensures two
NAT rules exist so locally-originated connections to the NAS's own LAN IP on a published
Docker port get hairpinned to the container. It's idempotent (checks before adding), so
re-running it on every boot is safe.

**This does not make `localhost`/`127.0.0.1:<port>` work from the host** — that would also
need `net.ipv4.conf.*.route_localnet=1`, which is `0` by default on this NAS, so loopback
traffic destined for the docker bridge gets dropped as a martian packet before it reaches
the container. Any host-side script that needs to reach a published port (see
`../scripts/tautulli_metadata.py`) should target the NAS's LAN IP instead of localhost.

## Rebuilding the toolchain from scratch

If `/volume1/dev/nvm` is ever empty (fresh NAS / lost volume), reinstall Node + Claude
as root, then run `relink-tools.sh`:

```sh
# Node via nvm (nvm needs bash, not ash):
bash -lc '
  export NVM_DIR=/volume1/dev/nvm
  mkdir -p "$NVM_DIR"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  . "$NVM_DIR/nvm.sh"
  nvm install --lts && nvm alias default "lts/*"
'
ln -sfn "$(ls -d /volume1/dev/nvm/versions/node/v* | sort -V | tail -1)" /volume1/dev/nvm/current
chmod -R a+rX /volume1/dev/nvm

# Wire up node/npm symlinks + per-user Claude data symlinks + aliases:
/volume1/dev/relink-tools.sh

# Claude Code — native, per user (run as each account; needs node on PATH):
export PATH="/volume1/dev/nvm/current/bin:$PATH"
curl -fsSL https://claude.ai/install.sh | bash      # installs to ~/.local/bin/claude
```

Each user's native install lives in `~/.local/bin/claude`; its `~/.local/share/claude`
cache is redirected to `/volume1/dev/claude/<user>` by `relink-tools.sh`, so nothing heavy
lands on the system partition. First run prompts login. To pre-seed JacquesRousseau's data
dir as root: `mkdir -p /volume1/dev/claude/JacquesRousseau/{share,config} && chown -R JacquesRousseau:users /volume1/dev/claude/JacquesRousseau`.

> If you previously had the npm-global package, remove it so the native install wins:
> `npm uninstall -g @anthropic-ai/claude-code` (then `relink-tools.sh` clears the stale
> `/usr/local/bin/claude` symlink). Confirm with `claude doctor` → *Currently running: native*.

## Notes / gotchas learned the hard way

- **`/usr/local/bin` is on the default PATH** for every user and shell — symlinking
  node/npm/npx there avoids all `.profile`/`NVM_DIR` fragility. This is the primary mechanism.
- **ash vs bash:** the Synology login shell is `ash`, which reads `~/.profile` (never
  `~/.bashrc`). bash interactive shells read `~/.bashrc`. Aliases are sourced from both.
  nvm only supports bash — it's needed for *installing* Node, not for *running* it.
- **Claude is per-user native, not a shared npm-global.** Claude Code self-migrates to a
  native install (`~/.local/bin/claude`) and self-updates; a shared npm-global launcher
  fights that (`claude doctor` flags "multiple installations"). Each user gets their own
  native install; `~/.claude` (credentials/state) and the `~/.local/share/claude` cache are
  per-user, the latter redirected to `/volume1`. Don't symlink `claude` into `/usr/local/bin`.
- **`authResponseHeaders` / X-Forwarded-For** and other Traefik specifics live in the parent
  repo, not here.

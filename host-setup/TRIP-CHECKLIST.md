# Trip checklist — running the NAS from an iPad (or any device) abroad

Quick field reference for administering the NAS remotely. The NAS lives on a LAN IP
(`192.168.1.156`) that is **not** reachable from outside — all remote access goes over
**Tailscale**.

## Connect

| What | How |
|---|---|
| NAS Tailscale IP | `100.78.157.40` (hostname `synology` on the tailnet) |
| SSH (as your user) | `ssh -p 49157 JacquesRousseau@100.78.157.40` |
| DSM web UI | `https://100.78.157.40:5001` in Safari, or `https://synology.<domain>` via Traefik/Cloudflare |
| Run Claude | SSH in as JacquesRousseau, then `claude` |

**iPad apps:** Blink Shell or Termius (SSH), Working Copy (git), Safari (DSM). Set up an SSH
key in the client to avoid typing the password each time.

## Before you leave (do these on the LAN)

- [ ] **Tailscale on the iPad** — install, sign in (SlackCollective tailnet), confirm `jripad`
      shows **online** and can `ssh -p 49157 JacquesRousseau@100.78.157.40`.
- [ ] **Disable key expiry** for the NAS (`synology`) and iPad (`jripad`) nodes in the
      Tailscale admin console — default keys expire ~6 months and would strand you mid-trip.
- [ ] **Dry-run from the iPad** on cellular/hotspot (not home wifi): SSH in, run `claude --version`.
- [ ] Confirm the **boot task** is registered (Control Panel → Task Scheduler → Boot-up →
      `sh /volume1/dev/relink-tools.sh`).

## Claude install layout (so you know what "healthy" looks like)

- Single **native** install per user; `claude doctor` should say *Currently running: native*,
  **no "multiple installations" warning**.
- JacquesRousseau: `/volume1/homes/JacquesRousseau/.local/share/claude` (home is on /volume1).
- root: `/root/.local/bin/claude` launcher, cache redirected to `/volume1/dev/claude/root`.
- node/npm/npx: shared via `/usr/local/bin` symlinks → `/volume1/dev/nvm/current/bin`.

## Recovery (if something breaks abroad)

**`node`/`npm`/`claude` not found, or links missing after a reboot/DSM reset:**
```sh
sudo sh /volume1/dev/relink-tools.sh        # re-creates /usr/local/bin links + root's claude symlinks
hash -r
```

**`claude` says "missing or broken" (as JacquesRousseau):**
```sh
ls -lad ~/.local/share/claude               # if it's a symlink into /volume1/dev/claude, remove it
rm -f ~/.local/share/claude                 # (links only — never rm the ~/.claude dir)
claude install
```

**`claude doctor` shows "multiple installations" / wrong version:**
```sh
# the culprit is almost always a leftover npm-global in the shared node (run as root):
npm uninstall -g @anthropic-ai/claude-code
hash -r && claude doctor                    # should now be: native, single install
```

**Reinstall claude from scratch (per user; needs node on PATH):**
```sh
export PATH="/volume1/dev/nvm/current/bin:$HOME/.local/bin:$PATH"
curl -fsSL https://claude.ai/install.sh | bash
```

**DSM update blocked by full system partition** — the system partition `/` (`md0`, ~2.3 GB) is
the constraint, NOT `/volume1`. Free space on `/`, not on the data volume:
```sh
sudo du -xh -d1 / 2>/dev/null | sort -rh | head     # find the hog (usually /root caches)
df -h /                                              # confirm headroom before updating
```

## Notes

- The whole `/volume1/dev` toolchain survives reboots/resets via the boot task; data on
  `/volume1` is never wiped. See `README.md` here for the full design and a from-scratch rebuild.
- root's PATH is fragile (DSM resets `/root`), so root's `claude` may need
  `export PATH="$HOME/.local/bin:$PATH"` per session. JacquesRousseau is the stable account.

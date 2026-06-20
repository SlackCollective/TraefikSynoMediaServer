# shell-aliases.sh — shared interactive aliases for root + JacquesRousseau.
# Sourced (not executed) from each account's ~/.profile and ~/.bashrc.
# Keep everything POSIX so it works in BOTH ash (Synology default) and bash.
# Deploy to: /volume1/dev/shell-aliases.sh   (world-readable: chmod a+r)

# --- PATH: ensure each account's native ~/.local/bin (claude, etc.) resolves ---
# Idempotent — won't duplicate if already present. Lets root's native claude be found
# without a separate profile edit (root's home is on the fragile /root partition).
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# --- files / navigation ---
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias cdkr='cd /volume1/docker/apps'

# --- docker / compose ---
alias list='docker ps -a'
alias up='sudo docker compose up -d'
alias down='sudo docker compose down -v'      # NOTE: -v also removes anonymous/named volumes
alias pull='sudo docker compose pull'
alias inspect='sudo docker inspect'
alias start='sudo docker start'
alias stop='sudo docker stop'
alias prune='sudo docker system prune'

# logs <container> [args...] — a function, because an alias cannot consume "$@"
logs() { docker logs -tf --tail=50 "$@"; }

# claude — always start in the compose project dir, regardless of cwd
claude() { cd /volume1/docker/apps && command claude "$@"; }

# --- Synology permission fixes (see ../CLAUDE.md and ../README.md) ---
alias users='sudo chown -R docker:docker /volume1/data /volume1/docker/apps'
alias perms='sudo chmod -R a=,a+rX,u+w,g+w /volume1/data /volume1/docker/apps'

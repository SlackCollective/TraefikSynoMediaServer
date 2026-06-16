# shell-aliases.sh — shared interactive aliases for root + JacquesRousseau.
# Sourced (not executed) from each account's ~/.profile and ~/.bashrc.
# Keep everything POSIX so it works in BOTH ash (Synology default) and bash.
# Deploy to: /volume1/dev/shell-aliases.sh   (world-readable: chmod a+r)

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

# --- Synology permission fixes (see ../CLAUDE.md and ../README.md) ---
alias users='sudo chown -R docker:docker /volume1/data /volume1/docker/apps'
alias perms='sudo chmod -R a=,a+rX,u+w,g+w /volume1/data /volume1/docker/apps'

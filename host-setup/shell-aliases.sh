# shell-aliases.sh — shared interactive aliases for root + JacquesRousseau.
# Sourced (not executed) from each account's ~/.profile and ~/.bashrc.
# Keep everything POSIX so it works in BOTH ash (Synology default) and bash.
# Deploy to: /volume1/dev/shell-aliases.sh   (world-readable: chmod a+r)

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Docker / compose
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}"'
alias dlogs='docker logs -f'

# add your own below this line ----------------------------------------------

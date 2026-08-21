#!/usr/bin/env bash
# Runs once per machine (chezmoi tracks it by content hash). Idempotent, no root.
set -euo pipefail

mkdir -p "$HOME/.ssh" "$HOME/.cache/zsh" "$HOME/.local/bin"
chmod 700 "$HOME/.ssh" 2>/dev/null || true   # read-only mount in devcontainers

# starship prompt
if ! command -v starship >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/starship" ]; then
    curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y
fi

# pixi (per-project Python/geospatial envs)
if ! command -v pixi >/dev/null 2>&1 && [ ! -x "$HOME/.pixi/bin/pixi" ]; then
    curl -fsSL https://pixi.sh/install.sh | PIXI_NO_PATH_UPDATE=1 sh
fi

# ssh key for this machine (public key must then be added to GitHub etc.)
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -C "mtontsch@$(hostname)"
    echo ">>> New SSH key generated. Add this public key to GitHub:"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

if ! command -v zsh >/dev/null 2>&1; then
    echo ">>> zsh is not installed on this machine (needs root: apt install zsh)"
fi

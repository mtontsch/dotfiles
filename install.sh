#!/bin/sh
# Entry point for VS Code's dotfiles.installCommand (runs inside devcontainers).
# Installs chezmoi if missing, then applies this repo (already cloned by VS Code
# to the directory this script lives in). Defaults role=work for containers.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

chezmoi init --apply --promptString role=work --source="$SCRIPT_DIR"

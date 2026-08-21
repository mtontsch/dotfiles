# dotfiles

Personal configuration, managed with [chezmoi](https://chezmoi.io). Covers zsh,
starship, tmux, git, ssh, Claude Code, and Codex. Python/geospatial environments
are per-project via [pixi](https://pixi.sh) and live in each project repo, not here.

## New machine (or new devcontainer)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply mtontsch/dotfiles
```

You'll be asked once whether the machine is `work` or `personal` — this selects
the git identity (unibw vs gmx). Repos under `~/personal/` always use the
private identity. The bootstrap script installs starship + pixi (no root) and
generates a per-machine ssh key; add its `.pub` to GitHub.

Then, if desired: `chsh -s /usr/bin/zsh`

## Daily use

| Task | Command |
|---|---|
| Edit a managed file | `chezmoi edit ~/.zshrc` then `chezmoi apply` (alias `cza`) |
| See pending changes | `chezmoi diff` (alias `czd`) |
| Adopt an edit made directly in `~` | `chezmoi re-add` |
| Add a new file to management | `chezmoi add ~/.foo` |
| Sync to/from GitHub | `chezmoi cd` then normal git |

## VS Code integration

User setting on every UI machine (synced by Settings Sync):

```json
"dotfiles.repository": "mtontsch/dotfiles",
"dotfiles.installCommand": "install.sh"
```

so every devcontainer gets these dotfiles automatically.

## Never in this repo

SSH private keys (regenerate per machine), `~/.codex/auth.json`,
`~/.git-credentials`, OAuth tokens, anything under `~/.claude/` except
`settings.json` and `skills/`.

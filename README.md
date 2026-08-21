# dotfiles

Personal configuration, managed with [chezmoi](https://chezmoi.io). Covers zsh,
starship, tmux, git, ssh, conda, Claude Code, and Codex. Python/geospatial
environments are per-project via [pixi](https://pixi.sh) and live in each
project repo, not here.

**This repo is private.** Cloning therefore always goes over SSH, which means a
machine needs its SSH key registered on GitHub *before* it can bootstrap.

## New machine

```sh
# 1. key first (the repo is private)
ssh-keygen -t ed25519 -C "mtontsch@$(hostname)"
cat ~/.ssh/id_ed25519.pub      # -> GitHub > Settings > SSH keys (and GitLab)

# 2. bootstrap
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin \
    init --apply git@github.com:mtontsch/dotfiles.git

# 3. optional
chsh -s /usr/bin/zsh
```

You'll be asked once whether the machine is `work` or `personal`; this sets the
default git identity (unibw vs proton). Repos on git.unibw.de always commit as
unibw, repos on github.com always as proton, regardless of the default.
The bootstrap script installs starship + pixi (no root needed).

## How chezmoi works

Every managed file exists twice: the **source** in this repo
(`~/.local/share/chezmoi/dot_zshrc`) and the **target** in `$HOME` (`~/.zshrc`).
`chezmoi apply` copies source -> target. Git tracks the source.

| I want to… | Do |
|---|---|
| Change a config | `chezmoi edit ~/.zshrc` then `chezmoi apply` (alias `cza`) |
| …or experiment on the real file first | edit `~/.zshrc` directly, then `chezmoi re-add` to copy it back into the source |
| See what `apply` would change | `chezmoi diff` (alias `czd`) |
| Put a new file under management | `chezmoi add ~/.config/htop/htoprc` (dirs work too) |
| Stop managing a file | `chezmoi forget ~/.foo` (keeps the target) |
| Save + sync | `chezmoi cd` then `git add -A && git commit -m "…" && git push` |
| Pull changes on another machine | `chezmoi update` (= git pull + apply) |

Rules of thumb:

- `apply` **overwrites** target files with the source. If you edited a target
  directly, `re-add` first (or check `chezmoi diff`) or you lose the edit.
- Never `chezmoi add` secrets (keys, `auth.json`, tokens, `.git-credentials`).
  Private repo or not, they don't belong in git.
- Files ending in `.tmpl` are templates: `.role` and `.chezmoi.hostname` are
  available inside `{{ }}`. Only template a file that genuinely differs between
  machines (see `dot_gitconfig.tmpl`).
- Source filenames encode attributes: `dot_` = leading dot, `private_` = mode
  600/700, `run_once_` = script run once per machine.

## Devcontainers

Two mechanisms apply these dotfiles inside containers:

1. VS Code user setting (synced by Settings Sync to every UI machine):
   ```json
   "dotfiles.repository": "git@github.com:mtontsch/dotfiles.git",
   "dotfiles.installCommand": "install.sh"
   ```
2. Fallback in each project's `postCreateCommand.sh`.

Both need the host's `~/.ssh` bind-mounted read-only into the container
(see DeepSeepNet's `devcontainer.json`) so the private clone — and `git push`
from inside the container — can authenticate.

## Never in this repo

SSH private keys (generate per machine), `~/.codex/auth.json`,
`~/.git-credentials`, OAuth tokens, anything under `~/.claude/` except
`settings.json` and `skills/`.

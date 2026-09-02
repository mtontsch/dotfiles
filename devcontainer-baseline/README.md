# Devcontainer baseline

Reusable `.devcontainer/` template for Linux servers with NVIDIA GPUs, geared
toward Python/geospatial/DL projects and safe operation of unsupervised LLM
agents (Claude Code, Codex) inside the container. The files are the working
**tileforge** setup: project- and user-level values are literal, host-level
values are `${localEnv:TF_*:default}` with the **dgx1** values as defaults;
every known host exports its `TF_*` set explicitly via the chezmoi-managed
`~/.profile` — so one committed `devcontainer.json` serves every host (see
"Per-host values"). Per-project variants live in each project's
`.devcontainer/` (versioned with the project); per-host values live here in
`dot_profile.tmpl`. One branch — never encode hosts or projects as git
branches of this repo.

## Design decisions baked in

- **Container = agent sandbox**: non-root user, sudo purged and every setuid/
  setgid bit stripped from the image (root via `docker exec -u root` from the
  host), `no-new-privileges`, `--pids-limit`, `init: true`. Known gaps: open
  network egress; read-write bind mounts; no `--memory`/`--cpus` caps by default.
- **Same-path mounts**: repo and data store keep their host paths inside the
  container. One path dialect everywhere — venv shebangs, git worktrees, and
  Claude Code project history stay valid on both sides of the boundary.
  `.code-workspace` files live gitignored in the repo root, so they ride the
  workspace mount and need no mount of their own.
- **`--shm-size` instead of `--ipc=host`** (what PyTorch actually needs).
- **uv-managed venv** in the repo + a named volume for the uv wheel cache so
  rebuilds don't re-download torch/CUDA.
- **Persistent container**: `--restart=unless-stopped`, `shutdownAction: none`;
  day-to-day you attach, you don't relaunch.
- **Chezmoi shell config everywhere**: postCreate bootstraps this dotfiles repo
  into `~/.local/share/chezmoi` and applies it, so container shells match host
  shells (starship, plugins, aliases). Container-specific lines (venv
  activation, `CLAUDE_CONFIG_DIR`) go to `~/.zshrc.local`, sourced by the
  managed `~/.zshrc`. Rebuilds need github.com/mtontsch/dotfiles reachable.
- **No `CLAUDE_CODE_OAUTH_TOKEN` in `remoteEnv`**: an env token silently
  overrides the stored login in the bind-mounted `~/.claude` and goes stale
  (the "Fable (disabled)" incident, Aug 2026). The mount carries the login.
- **Day-to-day entry**: `devcon [container] [session]` from the host (deployed
  to `~/.local/bin` by chezmoi) or the `dev` alias in any container shell —
  both land in the `dev` tmux session, where `claude` keeps running across
  detaches and SSH disconnects.

## Adapting to a new project / server

Copy the three files into `<project>/.devcontainer/`, then work through the
tags — `grep -rn 'SPECIFIC' .devcontainer/`:

**[PROJECT-SPECIFIC]** (per repository)
- `name` in devcontainer.json, `--name` in runArgs, uv-cache volume name
- the `uv sync --extra <name>` extra in postCreateCommand.sh (must exist in
  the project's `pyproject.toml`)
- base image + apt packages in the Dockerfile (this one is CUDA + QGIS/GDAL)

**[SERVER-SPECIFIC]** (per host) — NOT edited in the file. Every host-level
value is `${localEnv:TF_*:default}`; set the `TF_*` variables for the host
instead (next section). The defaults are the dgx1 values.

**[USER-SPECIFIC]**
- `USERNAME` in `build.args`, `containerUser`/`remoteUser`, the `/home/<user>`
  paths in mounts and `remoteEnv` — the account name (not its numeric ids)
- git identity needs no entry: the chezmoi-applied `~/.gitconfig` carries it
  (forge-based includeIf)

## Per-host values

`devcontainer.json` reads these from the environment of the **VS Code server
process on the host** (Remote-SSH: the SSH host), falling back to the dgx1
value when unset:

| variable            | meaning                                           | dgx1 default        | iota                  |
|---------------------|---------------------------------------------------|---------------------|-----------------------|
| `TF_UID` / `TF_GID` | host user's `id -u` / `id -g`                     | `1005` / `1005`     | `1001` / `1001`       |
| `TF_DATA_GID`, `TF_DATA_GID2` | groups owning the data mount (`stat -c %g`); set both to the same id if there is only one | `1002`, `1003` | `100`, `100` |
| `TF_DATA_ROOT`      | data store, same-path bind mount (narrowest subtree) | `/mnt/data/hegemon` | `/mnt/data`        |
| `TF_SHM_SIZE`       | `--shm-size`                                      | `64g`               | `64g`                 |

They live in `dot_profile.tmpl` in this repo, branched on the trimmed output of
`hostname`. Do not use `.chezmoi.hostname` for this: chezmoi can canonicalize it
through reverse DNS (on dgx1 it resolves to `localhost6`).
`~/.profile` is what VS Code's login-shell environment resolution reads on a
bash-login host (dgx1); `~/.zshenv` sources it so zsh hosts/sessions get the
same values. (A `~/.zshenv`-only version silently failed on dgx1 — the login
shell there is bash.) Every known host exports its full `TF_*` set explicitly,
even where values match a project's fallbacks — projects are then free to pick
their own fallbacks (tileforge's are dgx1's, DeepSeepNet's are iota's), and a
broken resolution path is visible on every host. To add a host (e.g. pontus):
fill in its branch in `dot_profile.tmpl`, `chezmoi apply`, then rebuild.
Verify resolution end-to-end with the canary described under failure modes
before trusting it.

## First launch on a fresh server

```bash
cd <project>
npx --yes @devcontainers/cli up --workspace-folder .   # or VS Code: F1 → Reopen in Container
```

Then in VS Code (Remote-SSH window): open the project folder → F1 →
"Dev Containers: Reopen in Container". Multi-root view: open your
`.code-workspace` from inside the container once; afterwards use its
`[Dev Container]` entry in the Recent list.

## Failure modes already paid for (don't rediscover them)

- Wrong `USER_UID` → container user can't read the repo; postCreate dies with
  `Permission denied` (exit 126).
- uv cache volume seeded root-owned → `uv sync` fails; the Dockerfile
  pre-creates `~/.cache/uv` with the right owner to prevent this.
- `uv sync --reinstall` without the project's `--extra` strips the extra's
  packages — always pass the extra.
- "Open Workspace in Container" requires the `.code-workspace` to sit next to
  `.devcontainer/` and all folders under it — use the attach-then-open flow
  for multi-root workspaces instead.
- A stale running container holding the fixed `--name` blocks rebuilds, and
  VS Code's "Rebuild Container" does not reliably remove it:
  `docker rm -f <name>` on the host first.
- VS Code connected before postCreate finished → the first terminal after a
  rebuild was a bare zsh (no `~/.zshrc` yet). `"waitFor": "postCreateCommand"`
  fixes it; the cost is a longer "Starting Dev Container" on cold rebuilds.
- The Python extension auto-sourced a stale sibling venv (`.venv.old-*`) it
  had cached as the interpreter. `python.defaultInterpreterPath` is pinned to
  `.venv` and the extension's terminal activation is off (`~/.zshrc.local`
  activates). Delete stale sibling venvs anyway.
- `TF_*` resolution silently failing on a host whose values equal a project's
  fallbacks: everything works there and the *other* host breaks with the
  wrong-UID failure above. Canary after touching the mechanism: export one
  observable non-default (e.g. `TF_SHM_SIZE=65g`), rebuild, and check
  `docker inspect -f '{{.HostConfig.ShmSize}}' <name>` on the host
  (65g = 69793218560); then remove it and rebuild again.
- A `~/.tmux.conf` file (e.g. symlinked by an older postCreate) silently
  shadows the chezmoi-managed `~/.config/tmux/tmux.conf` — tmux prefers the
  home-dir path. Delete it; nothing should create it.
- `devcon` / plain `docker exec` shells started in `/home/jovyan` (read-only,
  lock icon in the prompt): the base image's WORKDIR leaks through — `docker
  exec` uses it, VS Code terminals don't. The Dockerfile now sets `WORKDIR
  /home/${USERNAME}` and `devcon` anchors the tmux session to `$HOME` via
  `attach-session -c` / `new-session -c` (`new-session -A` ignores `-c` for
  an existing session), so an old session is repaired on the next attach.
- `11;rgb:0c0c/0c0c/0c0c` typed into the pane when attaching through Windows
  Terminal + Windows `ssh.exe`: tmux's OSC 10/11 colour query reply arriving
  too late for a 10 ms `escape-time`. The chezmoi tmux.conf uses 50 ms; a
  newer tmux does not help (reported on 3.5a too).

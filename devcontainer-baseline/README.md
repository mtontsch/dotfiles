# Devcontainer baseline

Reusable `.devcontainer/` template for Linux servers with NVIDIA GPUs, geared
toward Python/geospatial/DL projects and safe operation of unsupervised LLM
agents (Claude Code, Codex) inside the container. The values in the files are
the working **tileforge @ iota** setup, kept as a runnable example.

## Design decisions baked in

- **Container = agent sandbox**: non-root user, no sudo (root via
  `docker exec -u root` from the host), `no-new-privileges`, `--pids-limit`,
  `init: true`. Known gaps: open network egress; read-write bind mounts.
- **Same-path mounts**: repo, data store, and workspace-file directory keep
  their host paths inside the container. One path dialect everywhere — venv
  shebangs, git worktrees, `.code-workspace` files, and Claude Code project
  history stay valid on both sides of the boundary.
- **`--shm-size` instead of `--ipc=host`** (what PyTorch actually needs).
- **uv-managed venv** in the repo + a named volume for the uv wheel cache so
  rebuilds don't re-download torch/CUDA.
- **Persistent container**: `--restart=unless-stopped`, `shutdownAction: none`;
  day-to-day you attach, you don't relaunch.

## Adapting to a new project / server

Copy the four files into `<project>/.devcontainer/`, then work through the
tags — `grep -rn 'SPECIFIC' .devcontainer/`:

**[PROJECT-SPECIFIC]** (per repository)
- `name` in devcontainer.json, `--name` in runArgs, uv-cache volume name
- the `uv sync --extra <name>` extra in postCreateCommand.sh (must exist in
  the project's `pyproject.toml`)
- base image + apt packages in the Dockerfile (this one is CUDA + QGIS/GDAL)

**[SERVER-SPECIFIC]** (per host; get values with `id`, `getent group`,
`stat -c '%g' <mount>`)
- `build.args`: `USERNAME`, `USER_UID`, `USER_GID` — must match the host user
  or nothing in the bind mounts is readable
- `--group-add` ids for group-owned data mounts
- `--shm-size` (and optional `--memory`/`--cpus`) sized to the host
- the data-store and workspace-collection mounts (keep them same-path)

**[USER-SPECIFIC]**
- git identity in `remoteEnv`

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
- A stale running container holding the fixed `--name` blocks rebuilds:
  `docker stop <name> && docker rm <name>` first.

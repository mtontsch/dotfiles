# Baseline rollout: dgx1 → iota → pontus

Goal: every server runs the same personal workflow — chezmoi-managed shell
(zsh + starship + aliases) on host **and** in devcontainers, the devcontainer
baseline from this repo (`devcontainer-baseline/`), and the tmux+claude entry
points (`devcon` from the host, `dev` inside the container). Written Aug 2026,
after the dgx1/iota consolidation.

Ground rules that hold on every server:

- **Never** let `CLAUDE_CODE_OAUTH_TOKEN` reach the environment (shell rc
  files, devcontainer `remoteEnv`). It silently overrides the stored login in
  `~/.claude` and goes stale — symptom: model picker shows "Fable (disabled)"
  while the account has access. The `~/.claude` bind mount carries the login.
- The dotfiles repo must be **pushed before any container rebuild** anywhere:
  `postCreateCommand.sh` clones it from GitHub.
- Per-server container values live behind `[SERVER-SPECIFIC]` /
  `[PROJECT-SPECIFIC]` / `[USER-SPECIFIC]` tags — `grep -rn 'SPECIFIC'
  .devcontainer/` is the adaptation checklist (see
  `devcontainer-baseline/README.md`).

---

## Phase 0 — dgx1 (reference implementation, done first)

Already consolidated in the Aug 2026 session; kept here as the template.

1. Commit + push **dotfiles main** (baseline merge, chezmoi non-TTY init fix,
   `~/.zshrc.local` hook, `devcon`).
2. Commit **tileforge `.devcontainer/`** (baseline instantiated for dgx1:
   UID 1005, `--group-add 1002,1003`, `--shm-size=64g`, same-path
   `/mnt/data/hegemon` mount) on the working branch; push so iota/pontus can
   fetch it.
3. Rebuild test (the `/workspace` → same-path move breaks three things):

   ```bash
   cd ~/tileforge && rm -rf .venv          # venv is baked to the old path
   docker stop mt-tileforge-dev && docker rm mt-tileforge-dev   # fixed name blocks rebuild
   # VS Code: F1 → Dev Containers: Rebuild and Reopen in Container
   # then, inside the container:
   git worktree repair .worktrees/* && git worktree prune       # gitdir pointers said /workspace
   ```

4. Verify (this is the standard acceptance list, reused on every server):

   ```bash
   nvidia-smi                              # GPU visible to the non-root user
   echo $PWD                               # repo at its host path (same-path mount)
   zsh -ic 'whence dev; command -v starship claude codex'
   claude                                  # login OK, Fable enabled, no env token
   git -C .worktrees/<any> status -sb      # worktrees functional
   # from the HOST:
   devcon                                  # lands in the container's `dev` tmux session
   ```

Non-breaking fallout of the same-path move: Claude Code histories previously
keyed under `-workspace*` don't follow (new sessions share the host key —
intended); `/workspace` strings in config/provenance files are recorded
metadata, not resolved paths; CLAUDE.md still says `/workspace` in places
(docs drift, fix at leisure).

## Phase 1 — iota (migrate to the consolidated baseline)

iota created the baseline, so paths don't change there — lower risk than dgx1.
What DOES change: the container shell mechanism (retired `shell/zshrc` →
chezmoi everywhere) and the removed token forwarding.

1. **Host audit first** (the dgx1 incident pattern). LLM prompt:

   > Audit this host for stale Claude credentials: grep ~/.bashrc ~/.zshrc
   > ~/.profile ~/.zshenv and the current environment for
   > CLAUDE_CODE_OAUTH_TOKEN and sk-ant-. If an export exists, delete the
   > line, then kill the VS Code server processes on this host so extensions
   > stop inheriting it, and tell me to re-login in Claude Code. Report what
   > you found before changing anything.

2. **Update dotfiles on the host**: `chezmoi update` (pull + apply). Watch
   for: the pull deletes `shell/zshrc` — if the **container's** `~/.zshrc`
   sources it (pre-consolidation mechanism), container shells will error on
   startup until the rebuild in step 4. Harmless but noisy; the rebuild is
   the fix.
3. **Re-instantiate the tileforge `.devcontainer`** from the new baseline
   with iota's values. LLM prompt:

   > In this tileforge checkout, replace .devcontainer/ with the baseline
   > from ~/.local/share/chezmoi/devcontainer-baseline/ (Dockerfile and
   > postCreateCommand.sh verbatim; devcontainer.json filled in per its
   > SPECIFIC tags). Server values: get USERNAME/UID/GID from `id`, the
   > --group-add ids from `id` and `stat -c '%g'` on the data mount, size
   > --shm-size from /proc/meminfo. Keep iota's existing mounts: /mnt/data
   > same-path, ~/WORKSPACES_IOTA same-path, ~/.claude and ~/.codex binds,
   > and the uv-cache volume. Git identity: mtontsch /
   > maximilian.tontsch@unibw.de. Do NOT add CLAUDE_CODE_OAUTH_TOKEN to
   > remoteEnv under any circumstances. Do not commit; show me the diff and
   > a proposed commit message.

4. **Rebuild** the container (fixed `--name` → `docker stop` + `rm` the old
   one first; check `tmux ls` and `nvidia-smi` in it for running work
   before destroying). Paths are unchanged on iota, so no venv wipe and no
   worktree repair needed — but run the Phase-0 verify list anyway.
5. If iota's tileforge branch differs from where the dgx1 `.devcontainer`
   commit landed, cherry-pick or re-generate via the step-3 prompt — the
   baseline in the dotfiles repo is the source of truth, not the tileforge
   copy.

## Phase 2 — pontus (fresh server, the real test)

Nothing exists here; this proves the baseline is actually portable.

1. **Prerequisites** (need root/admin once): Docker with the NVIDIA
   Container Toolkit, and your user in the `docker` group. Verify:
   `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`.
2. **Host dotfiles**. LLM prompt:

   > Set up my dotfiles on this Linux host: clone
   > https://github.com/mtontsch/dotfiles to ~/.local/share/chezmoi and run
   > install.sh (installs chezmoi to ~/.local/bin, applies with role=work,
   > no TTY needed). The bootstrap generates ~/.ssh/id_ed25519 and prints
   > the public key — show it to me so I can add it to GitHub. Then make
   > interactive shells land in zsh: try `chsh -s $(command -v zsh)`; if the
   > account has no Unix password (SSH-key-only/LDAP), instead add a guarded
   > exec-zsh block at the top of ~/.bashrc ([ -t 1 ], zsh exists, not
   > already zsh). Finally grep shell rc files and env for
   > CLAUDE_CODE_OAUTH_TOKEN / sk-ant- and report any hits — do not create
   > any such export.

3. **Claude/Codex login**: `~/.claude` and `~/.codex` are fresh here. Run
   `claude` and `codex` once on the host and complete their logins BEFORE
   the first container build (the container bind-mounts these dirs and
   inherits the credentials).
4. **Project + container**. LLM prompt:

   > Clone the tileforge repo to ~/tileforge and check out <branch>. Copy
   > ~/.local/share/chezmoi/devcontainer-baseline/ files into
   > .devcontainer/ and fill the [SERVER-SPECIFIC] tags for this host:
   > USERNAME/UID/GID from `id`; --group-add from `stat -c '%g'` on the
   > data mount; --shm-size from /proc/meminfo; the data-store mount
   > same-path (ask me which path holds the project data on this server);
   > drop mounts that have no equivalent here. [PROJECT-SPECIFIC] values:
   > name tileforge-devcontainer, container name mt-tileforge-dev, volume
   > tileforge-uv-cache, uv extra "devcontainer". Git identity mtontsch /
   > maximilian.tontsch@unibw.de. Never add CLAUDE_CODE_OAUTH_TOKEN to
   > remoteEnv. Show me the filled values for confirmation before building.

5. Launch: VS Code Remote-SSH → open `~/tileforge` → F1 → "Reopen in
   Container" (or `npx --yes @devcontainers/cli up --workspace-folder .`).
6. Run the Phase-0 **verify list**. The workflow acceptance test is:
   `devcon` from the host → `claude` in the tmux pane → detach (prefix+d)
   → disconnect SSH → reconnect → `devcon` → claude still running.

## Failure modes → fixes

| Symptom | Cause | Fix |
|---|---|---|
| Model picker: "Fable (disabled)" | stale `CLAUDE_CODE_OAUTH_TOKEN` in env | delete the export (rc file or remoteEnv), kill VS Code server, re-login |
| postCreate dies, exit 126 / permission denied | `build.args` UID ≠ host UID | re-run `id`, fix `USER_UID`/`USER_GID`, rebuild |
| "name already in use" on rebuild | old container holds the fixed `--name` | `docker stop <name> && docker rm <name>` |
| container shells have no starship/aliases | dotfiles bootstrap failed (repo unreachable at rebuild, or old install.sh) | check postCreate log; repo must be public/pushed; install.sh must be post-fix (prompt key `role`) |
| `chezmoi init` hangs/fails on TTY | pre-fix install.sh (`--promptString` key mismatch) | pull dotfiles ≥ the Aug 2026 fix; or seed `~/.config/chezmoi/chezmoi.toml` with `[data] role = "work"` |
| `uv sync` permission denied on cache | uv-cache volume seeded root-owned | Dockerfile pre-creates `~/.cache/uv`; if hit anyway: `docker volume rm <vol>` and rebuild |
| venv broken after a mount-path change | `.venv` baked to old prefix | `rm -rf .venv`, let postCreate `uv sync` rebuild |
| `git` fails inside `.worktrees/*` | gitdir pointers reference old path | `git worktree repair .worktrees/*` then `git worktree prune` |
| `nvidia-smi` fails in container | NVIDIA Container Toolkit missing/stale on host | fix toolkit on host; only then consider `--privileged` |
| `chezmoi apply` balks: "settings.json has changed" | Claude Code harness rewrites `~/.claude/settings.json` | `chezmoi re-add ~/.claude/settings.json` (keep the live value) |
| `chsh` refuses / asks for unknown password | SSH-key-only or LDAP account | guarded `exec zsh` block at top of `~/.bashrc` |

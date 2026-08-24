#!/usr/bin/env bash
set -euo pipefail

# Repo path. Lifecycle commands run with cwd = the devcontainer.json
# "workspaceFolder"; with the same-path mount that equals the host repo path,
# so derive it instead of hardcoding either dialect.
WORKSPACE="$(pwd)"

# No sudo anywhere in this script (the container user deliberately has none —
# the container is the sandbox boundary for unsupervised agents). Root-level
# setup belongs in the Dockerfile; one-off root work goes through
# `docker exec -u root <container>` from the host.

# Link the tracked tmux config into HOME so it survives container rebuilds.
# Done first so a failure in a later step (e.g. uv sync) can't skip it.
ln -sf "${WORKSPACE}/.devcontainer/tmux.conf" "${HOME}/.tmux.conf"

# Ensure uv is available (it is already installed in the Dockerfile for normal
# builds; this is a fallback for exotic base-image swaps).
if ! command -v uv >/dev/null 2>&1; then
	curl -LsSf https://astral.sh/uv/install.sh | sh
	export PATH="${HOME}/.local/bin:${PATH}"
fi

# Install project + devcontainer dependencies into ${WORKSPACE}/.venv.
# The download cache (~/.cache/uv) is a named volume (see devcontainer.json),
# so rebuilds don't re-download the multi-GB torch/CUDA wheels.
# With the same-path mount the venv's shebangs are valid on the host too, but
# its interpreter and native libs live in the container image — treat the venv
# as container-first and re-run `uv sync` on the host if you need one there.
# [PROJECT-SPECIFIC] the extra name comes from the project pyproject.toml.
uv sync --extra devcontainer

# Install Claude Code CLI (native binary, self-updating, independent of the
# VS Code extension) so `claude` is on PATH in every shell/tmux pane.
# Container-local (~/.local), so a rebuild re-downloads it — rebuilds need
# network access to claude.ai, chatgpt.com, astral.sh.
if ! command -v claude >/dev/null 2>&1; then
	curl -fsSL https://claude.ai/install.sh | bash
fi

# Install Codex CLI (standalone Rust build — no Node, so it sidesteps the
# root-owned /usr/local npm prefix. CODEX_INSTALL_DIR puts the `codex` symlink
# inside the bind-mounted ~/.codex; the binary payload already lands under
# ~/.codex/packages/standalone, so the whole install persists across rebuilds.)
if ! command -v codex >/dev/null 2>&1; then
	curl -fsSL https://chatgpt.com/codex/install.sh \
		| CODEX_INSTALL_DIR="${HOME}/.codex/bin" CODEX_NON_INTERACTIVE=1 sh
fi

# Default Codex executor model. Repo policy (CLAUDE.md): gpt-5.6 always means
# gpt-5.6-sol; "high" is the default effort, tiered per task by the
# codex-worker skill. Only write if no config exists, so we never clobber one
# edited on the host (~/.codex is bind-mounted) — which also means: update THIS
# heredoc when the policy model changes, or the pin goes stale on new machines.
if [ ! -f "${HOME}/.codex/config.toml" ]; then
	cat > "${HOME}/.codex/config.toml" <<'EOF'
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
EOF
fi

# Claude Code skills need no install step here: ~/.claude is bind-mounted, so
# the host's skills (notably codex-worker, the authoritative Codex delegation
# entry point per CLAUDE.md) are visible inside the container automatically.

# Configure git identity once on container creation/rebuild.
# Values come from devcontainer.json remoteEnv ([USER-SPECIFIC] there).
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
	git config --global user.name "${GIT_USER_NAME}"
	git config --global user.email "${GIT_USER_EMAIL}"
else
	echo "GIT_USER_NAME / GIT_USER_EMAIL not set; skipping git identity config"
fi

# Auto-activate the project venv and enable uv completions in every zsh shell
# (and thus tmux panes). ~/.zshrc is container-local, so these appends restart
# from scratch on every rebuild; the grep guard makes reruns idempotent.
ZSHRC="${HOME}/.zshrc"
add_zshrc_line() {
	grep -qxF "$1" "${ZSHRC}" 2>/dev/null || echo "$1" >> "${ZSHRC}"
}
add_zshrc_line 'export PATH="${HOME}/.local/bin:${PATH}"'
# Make codex-worker + Claude config work in plain `docker exec` shells too
# (these normally come from devcontainer.json remoteEnv, which VS Code only
# injects into its own terminals — a raw docker exec shell wouldn't get them).
add_zshrc_line 'export PATH="${HOME}/.codex/bin:${PATH}"'
add_zshrc_line 'export CLAUDE_CONFIG_DIR="${HOME}/.claude"'
# Guarded so shells stay usable even if the venv is missing/broken.
add_zshrc_line "[ -f ${WORKSPACE}/.venv/bin/activate ] && source ${WORKSPACE}/.venv/bin/activate"
add_zshrc_line 'eval "$(uv generate-shell-completion zsh)"'
add_zshrc_line 'eval "$(uvx --generate-shell-completion zsh)"'

# Base: JupyterLab + CUDA + QGIS from b-data (third-party registry). The tag is
# pinned, but tags are mutable — for immutable builds pin the digest instead:
#   docker pull glcr.b-data.ch/jupyterlab/cuda/qgis/base:3.44.4-root
#   docker inspect --format='{{index .RepoDigests 0}}' <image>
# then FROM glcr.b-data.ch/jupyterlab/cuda/qgis/base@sha256:<digest>
FROM glcr.b-data.ch/jupyterlab/cuda/qgis/base:3.44.4-root

USER root

ARG DEBIAN_FRONTEND=noninteractive

# General tooling. Deliberately NO sudo: the container user must not be able to
# escalate (unsupervised agents run in here). For one-off root work use
# `docker exec -u root <container> bash` from the host; anything permanent
# belongs in this Dockerfile. bubblewrap is for Claude Code's sandbox mode
# (may still be blocked by the container's seccomp profile — the container
# itself is the primary sandbox).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git zsh curl wget ca-certificates \
        tmux \
        htop \
        nvtop \
        build-essential \
        openssh-client \
        nano \
        btop \
        ripgrep \
        tree \
        glances \
        rsync \
        bubblewrap \
        software-properties-common \
    && apt-get clean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Make "no sudo" literal: the base image ships sudo setuid, and with
# --security-opt=no-new-privileges it is merely inert. Purge it and strip the
# setuid/setgid bits image-wide (su, passwd, mount, ...) so a later config
# regression (someone dropping no-new-privileges while debugging) cannot turn
# a dormant escalation path back on. Nothing in an agent dev container needs
# setuid. (SUDO_FORCE_REMOVE: Ubuntu's sudo prerm refuses removal without it.)
# The find at the end prints anything still privileged into the build
# log — expect it to be empty.
RUN SUDO_FORCE_REMOVE=yes apt-get purge -y sudo \
    && rm -rf /etc/sudoers /etc/sudoers.d \
    && find / -xdev -perm /6000 -type f -exec chmod a-s {} + \
    && echo "remaining setuid/setgid files:" \
    && find / -xdev -perm /6000 -type f

# Geospatial native stack (GDAL/PROJ/spatialite CLIs + headers, GeographicLib/
# FFTW/GeoTIFF for rpcm). NOTE on reproducibility: ubuntugis-UNSTABLE tracks
# fresh GDAL releases whose behavior can shift between rebuilds — and the QGIS
# base image ships its own GDAL, while rasterio/pyogrio wheels vendor a third.
# The PPA mainly governs the CLI tools; if a rebuild changes vectorize/compose
# behavior, compare `gdalinfo --version` against
# `python -c "import rasterio; print(rasterio.gdal_version)"` first.
RUN apt-get update \
    && add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        geographiclib-tools libgeographiclib-dev libfftw3-dev libgeotiff-dev libtiff5-dev \
        libgdal-dev \
        gdal-bin \
        libproj-dev \
        libsqlite3-mod-spatialite \
        libspatialite-dev \
        spatialite-bin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv system-wide (/usr/local/bin) so it is on PATH for every user,
# including the non-root host-matching user created below. uv owns the project
# environment (postCreateCommand runs `uv sync`); the base image's pip is left
# untouched.
RUN curl -LsSf https://astral.sh/uv/install.sh \
      | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh

# ---- Non-root user matching the host user -------------------------------
# Run all interactive work as a normal user whose UID/GID match the host user,
# so bind-mounted files (the repo, ~/.claude, /mnt/data/...) keep the host
# user as owner. No sudoers entry on purpose — see the comment on the tooling
# block above.
# [SERVER-SPECIFIC] defaults; devcontainer.json build.args overrides them per
# host (that is the single place to adapt):
#   --build-arg USERNAME=$(id -un) --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g)
ARG USERNAME=mtontsch
ARG USER_UID=1001
ARG USER_GID=1001
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell "$(command -v zsh)" ${USERNAME}

# Pre-create the uv cache mountpoint owned by the user. devcontainer.json
# mounts a named volume there, and Docker seeds an EMPTY volume with this
# directory's content and ownership — if it doesn't exist in the image, the
# volume materializes root-owned and `uv sync` fails with Permission denied.
RUN mkdir -p /home/${USERNAME}/.cache/uv \
    && chown -R ${USER_UID}:${USER_GID} /home/${USERNAME}/.cache

# The base JupyterLab image bakes `ENV HOME=/home/jovyan` (the "jovyan"
# convention). Docker applies that inherited ENV to every process regardless of
# which user runs, so without this override $HOME stays /home/jovyan even though
# we run as ${USERNAME}. That mismatch breaks the ~/.claude and ~/.codex bind
# mounts (they target /home/${USERNAME}) and sends .zshrc and ~/.config to the
# wrong home. Pin HOME to the runtime user's actual home directory.
# Side effect: `docker exec -u root` shells also get this HOME, so root-run
# tools may drop root-owned files into ${USERNAME}'s home — if a mysterious
# root-owned ~/.cache appears, this is why.
ENV HOME=/home/${USERNAME}

# Same story for the working directory: the base image sets WORKDIR
# /home/jovyan, and `docker exec` (devcon, plain host-side shells) starts
# there — a read-only directory for ${USERNAME}. Anchor it to the user's home.
# Devcontainer lifecycle commands and VS Code terminals are unaffected (they
# use workspaceFolder). Placed after useradd so the directory already exists
# with the right owner; an earlier WORKDIR would create it root-owned.
WORKDIR /home/${USERNAME}

#!/usr/bin/env bash
set -euo pipefail

if ! command -v omarchy >/dev/null 2>&1; then
    exit 0
fi

echo -e "\n\033[1;34m==> Installing Omarchy packages\033[0m"

omarchy pkg add \
    chezmoi \
    eza \
    fd \
    ffmpeg \
    fzf \
    github-cli \
    ghostty \
    micro \
    mosh \
    obsidian \
    starship \
    tailscale \
    tmux \
    zed \
    zoxide

omarchy install browser zen || true
omarchy theme set "Tokyo Night" || true

echo -e "\033[1;32mOmarchy package setup complete.\033[0m"

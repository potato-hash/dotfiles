#!/bin/bash
set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

CHEZMOI_CONF="${HOME}/.config/chezmoi/chezmoi.toml"
if [ -f "$CHEZMOI_CONF" ]; then
    SOURCE_DIR="$(sed -n 's/^sourceDir *= *"\(.*\)"/\1/p' "$CHEZMOI_CONF")"
fi
SOURCE_DIR="${SOURCE_DIR:-${HOME}/.local/share/chezmoi}"
BREWFILE="${SOURCE_DIR}/Brewfile"

echo -e "\n\033[1;34m==> Installing packages from Brewfile\033[0m"
if [ -f "$BREWFILE" ]; then
    brew bundle --file="$BREWFILE" || echo "    ⚠ Some packages failed to install (continuing)"
    echo "    ✓ Brew bundle complete"
else
    echo "    ✗ Brewfile not found at $BREWFILE"
    exit 1
fi

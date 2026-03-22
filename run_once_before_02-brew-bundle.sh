#!/bin/bash
set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

SOURCE_DIR="$(chezmoi source-path 2>/dev/null || echo "${HOME}/.local/share/chezmoi")"
BREWFILE="${SOURCE_DIR}/Brewfile"

echo -e "\n\033[1;34m==> Installing packages from Brewfile\033[0m"
if [ -f "$BREWFILE" ]; then
    brew bundle --file="$BREWFILE" || echo "    ⚠ Some packages failed to install (continuing)"
    echo "    ✓ Brew bundle complete"
else
    echo "    ✗ Brewfile not found at $BREWFILE"
    exit 1
fi

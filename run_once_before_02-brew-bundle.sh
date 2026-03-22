#!/bin/bash
set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

BREWFILE="${HOME}/.local/share/chezmoi/Brewfile"

echo -e "\n\033[1;34m==> Installing packages from Brewfile\033[0m"
if [ -f "$BREWFILE" ]; then
    brew bundle --file="$BREWFILE" --no-lock || echo "    ⚠ Some packages failed to install (continuing)"
    echo "    ✓ Brew bundle complete"
else
    echo "    ✗ Brewfile not found at $BREWFILE"
    exit 1
fi

#!/bin/bash
set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

BREWFILE="${CHEZMOI_SOURCE_DIR:+${CHEZMOI_SOURCE_DIR}/Brewfile}"
if [ ! -f "$BREWFILE" ]; then
    BREWFILE="$(chezmoi source-path 2>/dev/null)/Brewfile"
fi
if [ ! -f "$BREWFILE" ]; then
    BREWFILE="${HOME}/.local/share/chezmoi/Brewfile"
fi

echo -e "\n\033[1;34m==> Installing packages from Brewfile\033[0m"
if [ -f "$BREWFILE" ]; then
    brew bundle --file="$BREWFILE"
    echo "    ✓ Brew bundle complete"
else
    echo "    ✗ Brewfile not found, skipping"
    exit 1
fi

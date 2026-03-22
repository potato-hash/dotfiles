#!/bin/bash
set -e

echo -e "\n\033[1;34m==> Installing Homebrew\033[0m"
if command -v brew &>/dev/null; then
    echo "    ✓ Homebrew already installed"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo "    ✓ Homebrew installed"
fi

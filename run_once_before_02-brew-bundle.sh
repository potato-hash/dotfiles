#!/bin/bash
set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

echo -e "\n\033[1;34m==> Installing packages from Brewfile\033[0m"
brew bundle --file="$(chezmoi source-path)/Brewfile"
echo "    ✓ Brew bundle complete"

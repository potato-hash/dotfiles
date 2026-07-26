#!/bin/bash
set -e

echo -e "\n\033[1;34m==> Configuring Zen Browser theme\033[0m"

CHEZMOI_CONF="${HOME}/.config/chezmoi/chezmoi.toml"
if [ -f "$CHEZMOI_CONF" ]; then
    SOURCE_DIR="$(sed -n 's/^sourceDir *= *"\(.*\)"/\1/p' "$CHEZMOI_CONF")"
fi
SOURCE_DIR="${SOURCE_DIR:-${HOME}/.local/share/chezmoi}"
ZEN_THEME_DIR="${SOURCE_DIR}/dot_config/zen-browser"

PROFILES_INI="${HOME}/Library/Application Support/zen/profiles.ini"
if [ ! -f "$PROFILES_INI" ]; then
    echo "    - Zen Browser not configured yet (skipped)"
    exit 0
fi

# Find the default profile path
PROFILE_REL="$(sed -n '/^\[.*\]/{h;d;}; /^Default=1/{g;p;q;}' "$PROFILES_INI" | sed 's/\[//' | sed 's/\]//')"
if [ -z "$PROFILE_REL" ]; then
    # Fall back to first profile with Path=
    PROFILE_REL="$(sed -n 's/^Path=//p' "$PROFILES_INI" | head -1)"
fi

if [ -z "$PROFILE_REL" ]; then
    echo "    ✗ Could not find Zen Browser profile"
    exit 1
fi

PROFILE_DIR="${HOME}/Library/Application Support/zen/${PROFILE_REL}"
CHROME_DIR="${PROFILE_DIR}/chrome"

mkdir -p "$CHROME_DIR"

cp "${ZEN_THEME_DIR}/chrome/userChrome.css" "$CHROME_DIR/"
cp "${ZEN_THEME_DIR}/chrome/userContent.css" "$CHROME_DIR/"
cp "${ZEN_THEME_DIR}/chrome/zen-logo-mocha.svg" "$CHROME_DIR/"
echo "    ✓ Catppuccin Mocha Pink theme installed"

cp "${ZEN_THEME_DIR}/user.js" "$PROFILE_DIR/"
echo "    ✓ Custom stylesheets enabled"

echo "    Restart Zen Browser to apply"

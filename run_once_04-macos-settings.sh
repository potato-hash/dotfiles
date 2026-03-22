#!/bin/bash

echo -e "\n\033[1;34m==> Configuring Dock & Finder\033[0m"

defaults write com.apple.dock autohide -bool true
echo "    ✓ Dock auto-hide enabled"

defaults write com.apple.dock tilesize -int 48
echo "    ✓ Dock tile size set to 48px"

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "    ✓ Show all file extensions"

defaults write com.apple.finder AppleShowAllFiles -bool true
echo "    ✓ Show hidden files in Finder"

defaults write com.apple.finder ShowPathbar -bool true
echo "    ✓ Show path bar in Finder"

echo -e "\n\033[1;34m==> Configuring Input & UX\033[0m"

defaults write NSGlobalDomain KeyRepeat -int 2
echo "    ✓ Key repeat rate set to fast"

defaults write NSGlobalDomain InitialKeyRepeat -int 15
echo "    ✓ Initial key repeat delay shortened"

defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
echo "    ✓ Autocorrect disabled"

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
echo "    ✓ Auto-capitalization disabled"

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
echo "    ✓ Tap-to-click enabled"

echo -e "\n\033[1;34m==> Applying changes\033[0m"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
echo "    ✓ Dock and Finder restarted"

echo -e "\n\033[1;32mSetup complete!\033[0m Restart your terminal to pick up the new .zshrc."

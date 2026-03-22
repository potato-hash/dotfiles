#!/bin/bash

# ── Dock ─────────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring Dock\033[0m"

defaults write com.apple.dock autohide -bool true
echo "    ✓ Auto-hide enabled"

defaults write com.apple.dock tilesize -int 48
echo "    ✓ Tile size set to 48px"

defaults write com.apple.dock autohide-delay -float 0
echo "    ✓ No show delay"

defaults write com.apple.dock autohide-time-modifier -float 0.4
echo "    ✓ Faster show/hide animation"

defaults write com.apple.dock show-recents -bool false
echo "    ✓ Recent apps section hidden"

defaults write com.apple.dock minimize-to-application -bool true
echo "    ✓ Minimize into app icon"

defaults write com.apple.dock mineffect -string "scale"
echo "    ✓ Scale minimize effect"

defaults write com.apple.dock launchanim -bool false
echo "    ✓ Launch bounce disabled"

defaults write com.apple.dock showhidden -bool true
echo "    ✓ Translucent icons for hidden apps"

# ── Dock App Layout ─────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Setting Dock app layout\033[0m"

if command -v dockutil &>/dev/null; then
    dockutil --remove all --no-restart
    dockutil --add /Applications/Ghostty.app --no-restart
    dockutil --add /Applications/Zed.app --no-restart
    dockutil --add /Applications/Claude.app --no-restart
    dockutil --add /Applications/Obsidian.app --no-restart
    dockutil --add /Applications/Discord.app --no-restart
    dockutil --add /Applications/Zen.app --no-restart
    dockutil --add ~/Downloads --view fan --display folder --no-restart
    echo "    ✓ Dock apps set"
else
    echo "    - dockutil not found (skipped)"
fi

# ── Hot Corners ──────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring hot corners\033[0m"

# Top-right: Put display to sleep
defaults write com.apple.dock wvous-tr-corner -int 10
defaults write com.apple.dock wvous-tr-modifier -int 0
echo "    ✓ Top-right: put display to sleep"

# ── Finder ───────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring Finder\033[0m"

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "    ✓ Show all file extensions"

defaults write com.apple.finder AppleShowAllFiles -bool true
echo "    ✓ Show hidden files"

defaults write com.apple.finder ShowPathbar -bool true
echo "    ✓ Show path bar"

defaults write com.apple.finder ShowStatusBar -bool true
echo "    ✓ Show status bar"

defaults write com.apple.finder _FXSortFoldersFirst -bool true
echo "    ✓ Folders sorted first"

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
echo "    ✓ Search current folder by default"

defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
echo "    ✓ Extension change warning disabled"

defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
echo "    ✓ Full POSIX path in title bar"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "    ✓ Default to list view"

defaults write com.apple.finder NewWindowTarget -string "PfHm"
echo "    ✓ New windows open Home"

# ── Input & UX ───────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring Input & UX\033[0m"

defaults write NSGlobalDomain KeyRepeat -int 2
echo "    ✓ Fast key repeat"

defaults write NSGlobalDomain InitialKeyRepeat -int 15
echo "    ✓ Short initial key repeat delay"

defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
echo "    ✓ Key repeat instead of accent picker"

defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
echo "    ✓ Autocorrect disabled"

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
echo "    ✓ Auto-capitalization disabled"

defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
echo "    ✓ Smart dashes disabled"

defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
echo "    ✓ Smart period substitution disabled"

defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
echo "    ✓ Smart quotes disabled"

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
echo "    ✓ Tap-to-click enabled"

# ── Save & Print ─────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring dialogs\033[0m"

defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
echo "    ✓ Save panels expanded by default"

defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
echo "    ✓ Print panels expanded by default"

defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
echo "    ✓ Save to disk by default (not iCloud)"

# ── Screenshots ──────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring screenshots\033[0m"

mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
echo "    ✓ Screenshots save to ~/Screenshots"

defaults write com.apple.screencapture type -string "png"
echo "    ✓ Screenshot format: PNG"

defaults write com.apple.screencapture disable-shadow -bool true
echo "    ✓ Window shadow disabled in screenshots"

defaults write com.apple.screencapture show-thumbnail -bool false
echo "    ✓ Floating thumbnail disabled"

# ── .DS_Store ────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring .DS_Store\033[0m"

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
echo "    ✓ No .DS_Store on network drives"

defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
echo "    ✓ No .DS_Store on USB drives"

# ── Security ─────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring security\033[0m"

defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "    ✓ Require password immediately after sleep/screensaver"

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null
echo "    ✓ Firewall enabled"

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null
echo "    ✓ Stealth mode enabled"

# ── Misc ─────────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Configuring misc settings\033[0m"

defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
echo "    ✓ Photos won't auto-launch on device connect"

defaults write com.apple.terminal SecureKeyboardEntry -bool true
echo "    ✓ Secure keyboard entry in Terminal"

# ── Default Apps ────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Setting default terminal and browser\033[0m"

defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
    '{LSHandlerRoleAll = "com.mitchellh.ghostty"; LSHandlerURLScheme = "terminal";}'
echo "    ✓ Ghostty set as default terminal"

defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
    '{LSHandlerRoleAll = "app.zen-browser.zen"; LSHandlerURLScheme = "http";}' \
    '{LSHandlerRoleAll = "app.zen-browser.zen"; LSHandlerURLScheme = "https";}'
echo "    ✓ Zen set as default browser"

# ── Apply changes ────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Applying changes\033[0m"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "    ✓ Dock, Finder, and SystemUIServer restarted"

echo -e "\n\033[1;32mSetup complete!\033[0m Restart your terminal to pick up the new .zshrc."

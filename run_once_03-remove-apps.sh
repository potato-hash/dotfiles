#!/bin/bash

echo -e "\n\033[1;34m==> Removing default apps\033[0m"

remove_app() {
    local app_path="$1"
    local app_name
    app_name="$(basename "$app_path" .app)"
    if [[ -d "$app_path" ]]; then
        if sudo rm -rf "$app_path" 2>/dev/null; then
            echo "    ✓ Removed $app_name"
        else
            echo "    ✗ Could not remove $app_name (SIP may be blocking)"
        fi
    else
        echo "    - $app_name not found (skipped)"
    fi
}

# System apps
remove_app "/System/Applications/Chess.app"
remove_app "/System/Applications/FaceTime.app"
remove_app "/System/Applications/Freeform.app"
remove_app "/System/Applications/Home.app"
remove_app "/System/Applications/Image Playground.app"
remove_app "/System/Applications/Journal.app"
remove_app "/System/Applications/Maps.app"
remove_app "/System/Applications/News.app"
remove_app "/System/Applications/Phone.app"
remove_app "/System/Applications/Photo Booth.app"
remove_app "/System/Applications/Podcasts.app"
remove_app "/System/Applications/Stocks.app"
remove_app "/System/Applications/Stickies.app"
remove_app "/System/Applications/Tips.app"
remove_app "/System/Applications/TV.app"

# User-level apps (may have been installed from App Store)
remove_app "/Applications/GarageBand.app"
remove_app "/Applications/iMovie.app"
remove_app "/Applications/Keynote.app"

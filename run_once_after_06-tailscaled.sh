#!/bin/bash
# Run the Homebrew tailscale formula's daemon as a boot-time system service, so
# the Mac can be a Tailscale SSH server. Signing in stays a manual step.
set -euo pipefail

echo -e "\n\033[1;34m==> Setting up tailscaled\033[0m"

if [ -d /Applications/Tailscale.app ]; then
    echo "    ✗ Tailscale.app conflicts with the open-source tailscaled." >&2
    echo "      Remove it, empty the Trash, reboot, then run chezmoi apply again." >&2
    exit 1
fi

prefix=$(/opt/homebrew/bin/brew --prefix)
for bin in tailscale tailscaled; do
    [ -x "$prefix/bin/$bin" ] || { echo "    ✗ $bin missing; run brew bundle first" >&2; exit 1; }
done

if [ -f /Library/LaunchDaemons/com.tailscale.tailscaled.plist ]; then
    echo "    ✓ tailscaled system daemon already installed"
else
    # A brew-services daemon from older setups would fight the system one.
    sudo launchctl bootout system/homebrew.mxcl.tailscale &>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist
    sudo "$prefix/bin/tailscaled" install-system-daemon
    echo "    ✓ tailscaled system daemon installed"
fi

if "$prefix/bin/tailscale" status &>/dev/null; then
    echo "    ✓ Signed in to Tailscale"
else
    echo "    Next: sudo tailscale up --ssh   (sign in through the browser link it prints)"
fi

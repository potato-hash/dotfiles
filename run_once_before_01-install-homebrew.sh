#!/bin/bash
set -euo pipefail

# ── Command Line Tools ───────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Checking Command Line Tools\033[0m"
if xcode-select -p &>/dev/null; then
    echo "    ✓ Command Line Tools present"
else
    xcode-select --install || true
    echo "    Finish the Command Line Tools dialog; this waits for it (up to 2 hours)."
    elapsed=0
    until xcode-select -p &>/dev/null; do
        if (( elapsed >= 7200 )); then
            echo "    ✗ Timed out waiting for Command Line Tools" >&2
            exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        (( elapsed % 60 == 0 )) && echo "    … still waiting ($((elapsed / 60)) min)"
    done
    echo "    ✓ Command Line Tools installed"
fi

# ── Homebrew ─────────────────────────────────────────────────────────────────
echo -e "\n\033[1;34m==> Installing Homebrew\033[0m"
if command -v brew &>/dev/null || [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
    echo "    ✓ Homebrew already installed"
else
    # Download to a private file first, so a cut-off transfer never runs half a script.
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$work/install.sh"
    /bin/bash "$work/install.sh"
    echo "    ✓ Homebrew installed"
fi

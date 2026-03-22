# dotfiles

Automated Mac setup — one command to go from a fresh macOS install to a fully configured machine.

## Setup

1. Complete macOS OOBE and sign into the App Store
2. Open Terminal and run:
   ```
   xcode-select --install
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply potato-hash
   ```
3. Restart your terminal

That's it. Everything below happens automatically.

## What It Does

### Packages (Brewfile)

**CLI tools:** chezmoi, eza, fd, ffmpeg, fzf, gemini-cli, gh, mas, micro, mosh, python 3.13, ssh-copy-id, starship, tailscale, tmux, zoxide

**Apps (Homebrew):** BetterDisplay, Bitwarden, Claude, Discord, Ghostty, GrandPerspective, Hush, Obsidian, qBittorrent, Zed

**Apps (Mac App Store):** Amphetamine, Apple Developer, TestFlight, Wipr, Xcode

**Go:** tailscale + tailscaled

### Dotfiles

- `.zshrc` — starship, fzf, zoxide, eza aliases, tmux auto-attach
- `.config/starship.toml` — compact prompt for mobile/remote use
- `.config/ghostty/config` — Ghostty terminal settings
- `.tmux.conf` — prefix key, mouse support, 256 color
- `.gitconfig` — git identity and gh credential helper
- `bin/claude-session` — tmux session helper for Claude Code

### App Removal

Removes: Chess, FaceTime, Freeform, GarageBand, Home, Image Playground, iMovie, Journal, Keynote, Maps, News, Phone, Photo Booth, Podcasts, Stocks, Stickies, Tips, TV

### macOS Settings

- **Dock:** auto-hide, 48px tile size
- **Finder:** show hidden files, file extensions, path bar
- **Keyboard:** fast key repeat, no autocorrect, no auto-capitalization
- **Trackpad:** tap-to-click

## Manual Installs

A few apps need manual download — see [MANUAL_INSTALL.md](MANUAL_INSTALL.md).

## Updating

```bash
# After changing a config locally:
chezmoi add ~/.config/ghostty/config    # update chezmoi's copy
chezmoi cd                               # cd into source repo
git add -A && git commit -m "..." && git push

# To pull changes on this machine:
chezmoi update
```

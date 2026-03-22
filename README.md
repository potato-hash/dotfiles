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

**CLI tools:** chezmoi, dockutil, eza, fd, ffmpeg, fzf, gemini-cli, gh, mas, micro, mosh, python 3.13, ssh-copy-id, starship, tailscale, tmux, zoxide

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

- **Dock:** auto-hide, 48px tiles, no delay, no recents, no bounce, scale minimize, custom app layout via dockutil
- **Hot corners:** top-right puts display to sleep
- **Finder:** hidden files, extensions, path bar, status bar, folders first, search current folder, list view, POSIX path in title
- **Keyboard:** fast key repeat, key repeat over accent picker, no autocorrect/auto-cap/smart dashes/smart quotes/smart periods
- **Trackpad:** tap-to-click
- **Dialogs:** expanded save/print panels, save to disk by default
- **Screenshots:** saved to ~/Screenshots as PNG, no shadow, no thumbnail
- **Storage:** no .DS_Store on network/USB drives
- **Security:** immediate screen lock, firewall on, stealth mode on, secure keyboard entry in Terminal
- **Misc:** Photos won't auto-launch on device connect

## Manual Installs

A few apps need manual download — see [MANUAL_INSTALL.md](MANUAL_INSTALL.md).

## Updating

```bash
# After changing a config locally:
chezmoi add ~/.config/ghostty/config    # update chezmoi's copy
cd ~/dotfiles && git add -A && git commit -m "..." && git push

# To pull changes on this machine:
chezmoi update
```

### Relocating the source directory

By default, `chezmoi init` clones to `~/.local/share/chezmoi`. To use `~/dotfiles` instead:

```bash
git clone https://github.com/potato-hash/dotfiles.git ~/dotfiles
echo 'sourceDir = "/Users/$USER/dotfiles"' > ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

### Discovering macOS settings

To find the `defaults write` command for a GUI setting:

```bash
defaults read > /tmp/before.plist
# Change something in System Settings...
defaults read > /tmp/after.plist
diff /tmp/before.plist /tmp/after.plist
```

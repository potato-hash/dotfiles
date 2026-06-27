# dotfiles

Automated setup for macOS and Omarchy Linux.

## macOS Setup

1. Complete macOS OOBE and sign into the App Store
2. Open Terminal and run:
   ```
   xcode-select --install
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply potato-hash
   ```
3. Restart your terminal

That's it. Everything below happens automatically.

## Omarchy Setup

Install Omarchy first, then apply the Linux side of these dotfiles:

```bash
omarchy pkg add chezmoi
chezmoi init --apply potato-hash
```

On Omarchy, chezmoi applies only the Linux-specific pieces:

- Bash profile that loads Omarchy's shell defaults
- Hyprland input settings for US + Colemak layout switching
- Hyprlock fingerprint unlock
- Git config using `/usr/bin/gh` as the credential helper
- Omarchy `theme-set` hook for `omazed`
- Idempotent Omarchy local setup script that installs preferred packages/apps, sets Tokyo Night/Ghostty/Zen/Zed defaults, patches app bindings, and removes redundant preinstalls while keeping Chromium for Omarchy web apps

The macOS terminal, prompt, tmux, Zed, Zen Browser, AeroSpace, Homebrew, and `defaults` scripts are ignored on Linux so they do not overwrite Omarchy's stock desktop behavior. The Omarchy setup script is ignored on macOS, so it cannot affect the macOS Homebrew/defaults setup.

## What It Does

### macOS Packages (Brewfile)

**CLI tools:** chezmoi, dockutil, eza, fd, ffmpeg, fzf, gemini-cli, gh, mas, micro, mosh, python 3.13, ssh-copy-id, starship, tailscale, tmux, zoxide

**Apps (Homebrew):** BetterDisplay, Bitwarden, Claude, Discord, Ghostty, GrandPerspective, Hush, Obsidian, qBittorrent, Zed

**Apps (Mac App Store):** Amphetamine, Apple Developer, TestFlight, Wipr, Xcode

**Go:** tailscale + tailscaled

### Shared/macOS Dotfiles

- `.zshrc` — starship, fzf, zoxide, eza aliases, tmux auto-attach
- `.config/starship.toml` — compact prompt with Catppuccin Mocha palette
- `.config/ghostty/config` — Ghostty terminal settings (Catppuccin Mocha)
- `.config/zed/settings.json` — Zed editor settings (Catppuccin Mocha)
- `.tmux.conf` — prefix key, mouse support, 256 color
- `.gitconfig` — git identity and gh credential helper
- `bin/claude-session` — tmux session helper for Claude Code

### macOS App Removal

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

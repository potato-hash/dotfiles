# dotfiles

Automated setup for macOS and Omarchy Linux.

## macOS Setup

1. Complete macOS OOBE and sign into the App Store
2. Open Terminal and install the command-line tools:
   ```bash
   xcode-select --install
   ```
3. Install chezmoi through Homebrew (`brew install chezmoi`) or from a pinned
   official release after verifying its published checksum. Do not pipe an
   unpinned remote installer into a shell.
4. Inspect the proposed changes before applying them:
   ```bash
   chezmoi init potato-hash
   chezmoi diff
   chezmoi apply
   ```
5. Restart your terminal.

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
- Oh My Pi (`omp`) agent settings
- Omarchy `theme-set` hook for `omazed`
- Transparent Waybar top bar styling
- Idempotent Omarchy local setup script that installs preferred packages/apps including Oh My Pi, sets Tokyo Night/Ghostty/Zen/Zed defaults, patches app/AI/GitHub bindings, removes redundant preinstalls, and keeps only Discord + YouTube from Omarchy's default web apps while preserving Chromium for web app support

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

## Remote Apple development

The chezmoi-managed config installs `apple-build` and `apple-dev-health` in
`~/.local/bin` on Linux and macOS, and installs `apple-build-worker` there on
macOS. It writes generic defaults to `~/.config/apple-dev/config`. Configure
an SSH alias named `apple-dev` in `~/.ssh/config` (with your own host, user,
and key); the public defaults never contain machine-specific connection
details.


`apple-dev-health` performs exactly one read-only SSH probe. It supports
`--json` for a stable object with `ok` plus the checks `reachable`, `macos`,
`omp`, `xcode`, `simulator_runtime`, `disk`, `hindsight`, `tart`, and
`stale_build_state`. Exit status `0` means no critical or warning checks,
`1` means warnings only, and `2` means at least one critical check or invalid
configuration. Configuration precedence is CLI > environment > config file >
defaults. Optional `APPLE_DEV_TART_VM` checks only that exact VM; an empty
value reports Tart installed/unconfigured without selecting a VM.

`apple-build --scheme NAME --action build|test [options] REPOSITORY` rejects
dirty repositories, resolves the requested revision to its exact commit, and
proves it is reachable from a branch or tag fetched fresh from the configured
origin. The controller sends one versioned request archive over stdin to the
fixed command `ssh HOST apple-build-worker`; build values never enter SSH
arguments or a remote shell command. The request contains only `manifest.json`
and `repository.bundle`.

The macOS deployment installs `apple-build-worker`. It accepts no arguments,
validates the streamed archive, checks out the bundled commit detached, and
runs `xcodebuild` with an argv array. Its stdout is only a compressed result
archive; diagnostics go to stderr. The result includes the request manifest,
`metadata.json`, `xcodebuild.log`, and `Result.xcresult` when produced, even
when the build fails. The worker drains all `xcodebuild` output but retains at
most 64 MiB of log text, then packages the result into a temporary archive
before emitting it. The controller receives stdout through a 4 GiB bounded
sink and independently validates the compressed archive, at most 250,000
members, at most 20 GiB of expanded member data, and at most 8 GiB per member
before reading metadata. These limits accommodate large Xcode result bundles
while bounding memory and disk exposure; metadata is read in bounded chunks.
The controller validates the result before atomically publishing it under
`--artifacts`; its exit status remains the worker build status, while missing
or invalid results are transport failures.

Exit status `125` is reserved for transport/protocol failure, and
`129`/`130`/`143` are reserved for controller signals. If `xcodebuild` itself
returns one of those values, the archive metadata preserves the exact status
while the worker and controller return generic Xcode failure status `65`.

For deterministic tests, `APPLE_BUILD_TEST_MAX_LOG_BYTES`,
`APPLE_BUILD_TEST_MAX_ARCHIVE_BYTES`, `APPLE_BUILD_TEST_MAX_MEMBERS`,
`APPLE_BUILD_TEST_MAX_EXPANDED_BYTES`, and
`APPLE_BUILD_TEST_MAX_MEMBER_BYTES` may lower the corresponding production
limits. Values that raise a production limit are rejected.

Worker jobs use `APPLE_DEV_WORK_ROOT` (default:
`~/Library/Caches/apple-build-worker`), separately from
`APPLE_DEV_BUILD_ROOT`, which remains the health-check DerivedData setting.
The worker also loads readable `~/.config/apple-dev/config` on the remote
host; an explicitly exported `APPLE_DEV_WORK_ROOT` takes precedence.
Requests are capped at 500 MiB, with a 64 KiB manifest limit and a 499 MiB
bundle limit. Stale cleanup is limited to direct worker-created `job.*`
directories older than one day. Each live job carries its worker PID; cleanup
retains a job when that PID still exists, so ambiguous PID reuse preserves
stale state rather than risking deletion of a live build. The worker account
must be dedicated and trusted to build the submitted repository: Xcode build
phases execute repository code with that account's permissions.

For a first macOS apply:

```bash
xcode-select --install
brew install chezmoi
chezmoi init potato-hash
chezmoi diff
chezmoi apply
```

If Homebrew is unavailable, install a pinned official chezmoi release only
after verifying its published checksum. Do not use an unpinned `curl | sh`
bootstrap.

Then edit `~/.ssh/config` and the generated Apple development config as
needed. No signing, CI, or application scaffolding is installed.

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

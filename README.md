# dotfiles

Chezmoi-managed dotfiles for a Mac, plus the shared prompt and tmux setup on
Linux and the PowerShell and Windows Terminal preferences on Windows.

## License

MIT; see [LICENSE](LICENSE). The Catppuccin theme for Zen Browser keeps its own
MIT notice; [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists the files,
source, copyright and license text.

## What each OS gets

| | macOS | Linux | Windows |
|---|---|---|---|
| zsh, git, Ghostty, Zed, Zen, AeroSpace, OMP | yes | | |
| Homebrew, Brewfile, `defaults` scripts | yes | | |
| `~/bin` helpers (`claude-session`, `clean-worktrees.sh`) | yes | | |
| `.tmux.conf` | yes | yes | |
| `.config/starship.toml` | yes | yes | yes |
| `apple-build`, `apple-dev-health`, `.config/apple-dev` | yes | yes | |
| `apple-build-worker` | yes | | |
| PowerShell profile block, Terminal paste setting | | | yes |

`.chezmoiignore` enforces this, and keeps the repository's own files
(`AGENTS.md`, `DESLOP.md`, `scripts/`, `tests/`, `Brewfile`, this README, the
licenses) out
of `$HOME`. Its patterns match target paths such as `.config/zed`, not source
names such as `dot_config/zed`.

Linux machines that run NixOS declare their shell, git and desktop in their own
NixOS or home-manager configuration, and these dotfiles do not repeat it. On
Linux chezmoi brings only what those configurations leave out: the tmux and
starship files and the Apple development clients.

OMP's `~/.omp/agent/config.yml` is seeded once (`create_` prefix): chezmoi
writes it only when it does not exist, because OMP rewrites it as you change
settings.

## macOS Setup

1. Complete macOS OOBE and sign into the App Store
2. Install the command-line tools:
   ```bash
   xcode-select --install
   ```
3. Install chezmoi through Homebrew (`brew install chezmoi`) or from a pinned
   official release after verifying its published checksum. Do not pipe an
   unpinned remote installer into a shell.
4. Inspect the proposed changes, then apply them:
   ```bash
   export DOTFILES_REPO='<dotfiles-repo-url>'
   chezmoi init "$DOTFILES_REPO"
   chezmoi diff
   chezmoi apply
   ```
5. Finish the steps that need a person:
   ```bash
   sudo tailscale up --ssh                    # sign in through the link it prints
   sudo xcodebuild -license accept            # once Xcode is installed
   sudo xcodebuild -runFirstLaunch
   ```
   Sign in to 1Password, then restart your terminal.

The first apply runs, in order:

1. Command Line Tools: starts Apple's installer if they are missing and waits
   for its dialog to finish.
2. Homebrew: downloads the official installer to a private temporary file,
   then runs it.
3. `brew bundle` from the Brewfile; it reruns whenever the Brewfile changes.
4. The dotfiles, then the macOS settings script (Dock, Finder, keyboard,
   security, power).
5. tailscaled: installs the Homebrew formula's daemon as a boot-time system
   service so the Mac can be a Tailscale SSH server. It stops if
   `Tailscale.app` is installed, since the two conflict. Leave
   `--accept-routes` off unless you need subnet routes.

Steps that need `sudo` prompt for it; the settings script skips a `sudo`
step it cannot run and says so.

## Linux Setup

```bash
export DOTFILES_REPO='<dotfiles-repo-url>'
chezmoi init "$DOTFILES_REPO"
chezmoi diff
chezmoi apply
```

## Windows Terminal

On Windows, `chezmoi apply` writes `~/.config/starship.toml` and runs one
script that keeps a marked `dotfiles terminal preferences` block in the
PowerShell 7 profile (PATH for winget and starship, `STARSHIP_CONFIG`,
PSReadLine in Emacs mode with history search, Ctrl+V bound to paste so a
multi-line script arrives as one editable block, zoxide, starship, eza
`ll`/`la`) and sets `"warning.multiLinePaste": false` in Windows Terminal. The
rest of the profile and of Terminal's settings is left as it is.

## What It Does on macOS

### Packages (Brewfile)

**CLI tools:** borders, chezmoi, dockutil, eza, fd, ffmpeg, fzf, gemini-cli, gh, jq, micro, mosh, starship, synergy-core, tailscale, tmux, zoxide

**Apps (Homebrew):** 1Password, 1Password CLI, AeroSpace, BetterDisplay, Claude, Claude Code, Discord, Ghostty, GrandPerspective, Hush, Iosevka, LocalSend, Obsidian, Zed, Zen

**Mac App Store apps are installed manually** (mas requires re-auth per app): Amphetamine, Apple Developer, TestFlight, Xcode

### Dotfiles

- `.zshrc`: zinit plugins, starship, fzf, zoxide, eza aliases, tmux helpers (tmux starts by hand, not at login)
- `.config/starship.toml`: compact prompt with Catppuccin Mocha palette
- `.config/ghostty/config`: Ghostty terminal settings (Catppuccin Mocha)
- `.config/zed/settings.json`: Zed editor settings (Catppuccin Mocha)
- `.config/aerospace/aerospace.toml`: tiling window manager keys and borders
- `.tmux.conf`: Ctrl+B prefix, mouse support, true color, Catppuccin status bar
- `.config/git/config`: git defaults, noreply identity and gh credential helper
- `.omp/agent/`: Oh My Pi settings (seeded once) and its Kanban and smoke-test overlays
- `bin/claude-session`: tmux session helper for Claude Code

### App Removal

Removes: Chess, FaceTime, Freeform, GarageBand, Home, Image Playground, iMovie, Journal, Keynote, Maps, News, Phone, Photo Booth, Podcasts, Stocks, Stickies, Tips, TV

### Settings

- **Dock:** auto-hide, 48px tiles, no delay, no recents, no bounce, scale minimize, custom app layout via dockutil
- **Hot corners:** top-right puts display to sleep
- **Finder:** hidden files, extensions, path bar, status bar, folders first, search current folder, list view, POSIX path in title
- **Keyboard:** fast key repeat, key repeat over accent picker, no autocorrect/auto-cap/smart dashes/smart quotes/smart periods
- **Trackpad:** tap-to-click
- **Dialogs:** expanded save/print panels, save to disk by default
- **Screenshots:** saved to ~/Screenshots as PNG, no shadow, no thumbnail
- **Storage:** no .DS_Store on network/USB drives
- **Security:** immediate screen lock, firewall on, stealth mode on, secure keyboard entry in Terminal
- **Power:** on the charger the system and display never sleep; restart after a power failure; wake for network access
- **Misc:** Photos won't auto-launch on device connect

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
`stale_build_state`. The `hindsight` check runs a read-only command only when
`APPLE_DEV_HINDSIGHT_HEALTH_COMMAND` is set; unset, it reports unconfigured.
Exit status `0` means no critical or warning checks,
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

Edit `~/.ssh/config` and the generated Apple development config as
needed. No signing, CI, or application scaffolding is installed.

## Updating

```bash
# After changing a config locally:
chezmoi add ~/.config/ghostty/config    # update chezmoi's copy
cd ~/dotfiles
scripts/scan-public.sh --history        # must pass before any push
git add -A && git commit -m "..." && git push

# To pull changes on this machine:
chezmoi update
```

This repository is public. `scripts/scan-public.sh` checks the working tree,
or with `--history` every reachable commit, for credential shapes, personal
home paths, private hostnames and addresses, and email addresses other than the
public noreply identity. It prints only file paths and the kind of match. Put
your own private markers (hostnames, tailnet name, real emails) in
`.git/info/public-scan-markers`, one extended regex per line; Git never pushes
that file. CI runs the same scan without your markers.

### Relocating the source directory

By default, `chezmoi init` clones to `~/.local/share/chezmoi`. To use `~/dotfiles` instead:

```bash
git clone "$DOTFILES_REPO" ~/dotfiles
printf 'sourceDir = "%s/dotfiles"\n' "$HOME" > ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

### Source repository

`DOTFILES_REPO` is the clone URL of the canonical copy of this repository on
your own Git host (reachable from the new machine). The GitHub copy (`potato-hash/dotfiles`) is an
automatic push-mirror of every branch of the canonical copy; still bootstrap
from the canonical copy. Once initialized, `chezmoi update` pulls from
whatever remote the source directory already has.

### Discovering macOS settings

To find the `defaults write` command for a GUI setting:

```bash
defaults read > /tmp/before.plist
# Change something in System Settings...
defaults read > /tmp/after.plist
diff /tmp/before.plist /tmp/after.plist
```

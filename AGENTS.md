# Dotfiles

Chezmoi-managed dotfiles for macOS, Linux and Windows. This repository is intentionally public.

## Public-Safety Policy

All committed content and reachable history must remain safe for public release.

Never commit secrets, real tailnet or internal hostnames, private IPs, infrastructure topology, personal paths or emails, device inventories, or private project or vault names.

Use placeholders, a GitHub noreply identity, environment variables, chezmoi templates, ignored local data, or encrypted chezmoi files for machine-specific values.

Before every push, run `scripts/scan-public.sh --history` and read the diff yourself. The script checks every file in every reachable commit for credential shapes, personal home paths, private hostnames and addresses, and email addresses other than the public noreply identity. Keep your own private markers (hostnames, tailnet name, real emails) in `.git/info/public-scan-markers`, one extended regex per line; that file is never pushed, so the markers never become public. CI runs the same scan without them. Deleting a line does not remove it from Git history.

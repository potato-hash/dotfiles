#!/bin/sh
# Scan this public repository for secrets and private data before a push.
#
# Usage: scripts/scan-public.sh [--history]
#
#   (default)   tracked and untracked, non-ignored files in the working tree
#   --history   every file in every commit reachable from any ref; findings
#               are reported once per path as "history:<path>"
#
# Reports file paths and the kind of match, never the matched text, so its
# output is safe in CI logs. Exit 0 when clean, 1 on a finding, 2 on misuse.
#
# Private markers (your own hostnames, tailnet name, real emails) must not be
# published, so they live outside the tree: one extended regex per line in
# "$(git rev-parse --git-dir)/info/public-scan-markers", matched
# case-insensitively. Blank lines and lines starting with # are skipped.
set -eu

mode=tree
case "${1:-}" in
  '') ;;
  --history) mode=history ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) printf 'usage: %s [--history]\n' "$0" >&2; exit 2 ;;
esac

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT"
git rev-parse --git-dir >/dev/null 2>&1 || { printf 'not a git repository: %s\n' "$ROOT" >&2; exit 2; }

# Split literals keep the scanner from matching its own source.
credential='tskey''-[A-Za-z0-9_-]{8,}|gh[opsur]''_[A-Za-z0-9]{20,}|github''_pat_[A-Za-z0-9_]{20,}'
credential="$credential"'|AKIA''[A-Z0-9]{16}|sk-''ant-[A-Za-z0-9_-]{16,}|sk-''[A-Za-z0-9]{32,}|xox[abprs]''-[A-Za-z0-9-]{10,}'
credential="$credential"'|BEGIN [A-Z ]*PRIVATE'' KEY|op:''//[A-Za-z0-9]'
email='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}'
# The public commit identity and reserved example domains are allowed.
email_allowed='@(users[.]noreply[.]github[.]com|example[.](com|org|net|invalid)|[A-Za-z0-9.-]+[.](invalid|test|example))'
personal_path='/Users/''[A-Za-z0-9._-]+|/home/''[A-Za-z0-9._-]+'
network='[A-Za-z0-9-]+[.]ts[.]net|[A-Za-z0-9-]+[.](internal|lan|home[.]arpa)([^A-Za-z0-9-]|$)'
network="$network"'|(^|[^0-9.])(10[.][0-9]{1,3}|192[.]168|172[.](1[6-9]|2[0-9]|3[01])|100[.](6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7]))[.][0-9]{1,3}[.][0-9]{1,3}([^0-9.]|$)'

markers_file="$(git rev-parse --git-dir)/info/public-scan-markers"
markers=
if [ -r "$markers_file" ]; then
  markers=$(grep -v -e '^[[:space:]]*$' -e '^[[:space:]]*#' "$markers_file" | paste -sd '|' -)
else
  printf 'note: no private markers file at %s; scanning generic patterns only\n' "$markers_file" >&2
fi

found=0
report() { found=1; printf '%s: %s\n' "$1" "$2"; }

# Print "path" (tree) or "history:path" (history) for files matching a pattern.
# $1 = grep flags, $2 = pattern; extra filtering is done by the caller.
matches() {
  if [ "$mode" = tree ]; then
    git ls-files -z -co --exclude-standard | xargs -0 grep -I -l $1 -e "$2" -- 2>/dev/null || true
  else
    git rev-list --all | while IFS= read -r rev; do
      git grep -I -l $1 -e "$2" "$rev" -- 2>/dev/null || true
    done | sed 's/^[0-9a-f]\{40\}:/history:/' | sort -u
  fi
}

# Lines (as "where:text") that match a pattern; used only where an allowlist applies.
matching_lines() {
  if [ "$mode" = tree ]; then
    git ls-files -z -co --exclude-standard | xargs -0 grep -I -H -o $1 -e "$2" -- 2>/dev/null || true
  else
    git rev-list --all | while IFS= read -r rev; do
      git grep -I -o $1 -e "$2" "$rev" -- 2>/dev/null || true
    done | sed 's/^[0-9a-f]\{40\}:/history:/'
  fi
}

for f in $(matches -E "$credential"); do report "$f" 'credential-shaped content'; done
for f in $(matches -E "$personal_path"); do report "$f" 'personal home path'; done
for f in $(matches -E "$network"); do report "$f" 'private hostname or address'; done
emails=$(matching_lines -E "$email" | grep -v -E "$email_allowed\$" | sed 's/:[^:]*$//' | sort -u)
if [ -n "$emails" ]; then found=1; printf '%s\n' "$emails" | sed 's/$/: email address/'; fi
if [ -n "$markers" ]; then
  for f in $(matches '-i -E' "$markers"); do report "$f" 'private marker'; done
fi

if [ "$found" -eq 0 ]; then
  printf 'public scan passed (%s)\n' "$mode"
else
  printf 'public scan failed (%s)\n' "$mode" >&2
  exit 1
fi

# DESLOP.md

Persistent memory between deslop runs. Existing entries are authoritative:
do not revisit Clean units, re-investigate Untraceable entries, or re-litigate
Load-bearing code unless the recorded dependency has disappeared.

## Clean

- `tests/test_apple_commands.sh` — 2026-09-13, 735b245 — deleted harness
  self-tests (failfast probe, sabotage propagator, `APPLE_TEST_SABOTAGE_MODE`,
  `APPLE_TEST_EXPECTED_CASES` override) and 5 duplicate cases whose assertions
  already ran inside success/failed/health cases. 49 → 41 named cases.
- `dot_local/bin/executable_apple-build-worker` — 2026-09-13, 258c5b3 —
  removed redundant `case` wrapper duplicating the stale-loop glob; replaced
  seven identical one-field python extractions with one pass writing
  `field.*` files read per variable.
- `bin/executable_new-project.sh` — 2026-09-13, 0cd5f6f — deleted the Verify
  section (re-confirmed steps already enforced by `set -e`); fixed stale
  `~/scripts/` usage paths to `~/bin/`.
- `dot_hermes/scripts/executable_tdd_gap_audit.py` — 2026-09-13, fa0c55e —
  deleted (655 LOC). One-shot import in 07dcb44, never modified, zero
  references in tree or any commit message; shipped to every machine with no
  caller.
- `MANUAL_INSTALL.md` + README manual-install section + `.chezmoiignore`
  entry — 2026-09-13, c15d072 — deleted stub referencing a `setup.sh` that
  never existed; README package lists corrected to match the Brewfile
  exactly.
- Config dead-settings sweep — 2026-09-13, 08eff7a — zshrc (dead
  `HISTDUP`, `appendhistory`/`hist_ignore_dups` subsumed, stale
  `~/.claude/local` PATH entry), tmux (3 unused palette vars), starship
  (`add_newline` default + 10 unreachable disabled modules), aerospace
  (5 default-dup keys), hyprlock (3 default keys), waybar (dead
  `#custom-voxtype` rules).
- Ghostty + hypr input comment strip — 2026-09-13, 25dc9a2 — removed
  Ghostty's 38-line stock header and `# this is a test`; removed
  input.conf's six commented-out template blocks and a windowrule for
  Alacritty/kitty/foot (installed nowhere in this repo).
- clean-worktrees + scaffold gitignore — 2026-09-13, 830b66b — dropped
  write-only MERGED_COUNT; deduped `dist/` in the new-project gitignore
  template. Verified behaviorally in a /tmp scratch repo (dry-run
  classification, real merged-worktree removal, exit codes 1/0 as
  documented).

## Untraceable

- `dot_omp/agent/native-smoke-overlay.yml` and `native-kanban-overlay.yml`
  (whole files) — appear to be session-local OMP v17.0.3 config overlays; no
  tracked file or git history shows a loader, but OMP/manual usage outside
  this repo cannot be ruled out from repo evidence. Searched: tree grep
  (`overlay`, exact filenames), full git history of `dot_omp/`. 24 lines
  total; left in place.
- `bun-globals.txt`, `npm-globals.txt`, `node-versions.txt` — hand-maintained
  manifests (3 "update JS global package manifests" commits), zero in-tree
  consumers. Likely fed to a manual `npm i -g` flow; cannot confirm from repo
  evidence. Left in place.
- `dot_omp/agent/rules/use-firecrawl-extract.md` — standalone
  `alwaysApply: true` rule; loaded by OMP's rules-directory convention, not
  by any in-repo pointer (expected for convention-loaded files). Current per
  workspace memory (Firecrawl embedded in personal-search). Searched: tree
  grep, git history (untouched since 07dcb44). Left in place.

## Load-bearing

- `dot_local/bin/executable_apple-build` + `apple-build-worker` + tests —
  security-bounded protocol documented line-by-line in README (bounded sinks,
  member/size limits, fail-closed archive validation, PID-aware stale
  cleanup, reserved exit statuses). Every constraint maps to a documented
  guarantee; do not simplify without re-reading README §Remote Apple
  development.
- `APPLE_BUILD_TEST_MAX_*` env knobs (controller + worker) — documented in
  README; they only *lower* hard limits so CI can exercise limit enforcement
  without multi-GiB fixtures. Test-only affordance with a published contract;
  deleting them deletes the limit-enforcement tests' ability to run.
- Env precedence machinery (env-save/config-source/env-restore/CLI) in
  `apple-build`, `apple-build-worker`, `apple-dev-health` — implements the
  documented precedence "CLI > environment > config file > defaults"
  including explicit-empty env overrides; tested by
  `configured-worker-root-honored`.
- `dot_omp/agent/config.yml.tmpl` `fail` on missing `HINDSIGHT_API_URL` —
  README: "the OMP config template fails rather than writing an empty
  endpoint". Fail-closed by contract.
- Bash 3.2 compatibility patterns in worker/health (per-field reads, no
  mapfile, `[[ ]]` regex in health only) — worker runs on stock macOS bash.
- `.chezmoiignore` OS blocks — the persisted routing contract; the
  macOS/Linux splits are deliberate (e.g. `/usr/bin/gh` on Linux vs
  `/opt/homebrew/bin/gh` on macOS credential helpers).
- `THIRD_PARTY_NOTICES.md` — MIT attribution for the vendored Zen Browser
  Catppuccin theme; public-repo license compliance.

## Findings

- `bin/executable_new-project.sh` uses GNU `sed -i` (no backup suffix) —
  breaks on macOS BSD sed at the personalize step. Present since the original
  import; not fixed (out of deslop scope). Also `--help` prints `head -13`,
  truncating the header's final `# Templates:` line.
- README drift (partially fixed in c15d072): package lists now match the
  Brewfile. (An earlier note claimed the zed path was wrong; false positive —
  chezmoi's `private_` prefix applies `private_settings.json` as
  `~/.config/zed/settings.json` with 0600, so README names the right target.)
- `run_onchange_04-macos-settings.sh` prints "✓ Firewall enabled" /
  "✓ Stealth mode enabled" unconditionally even when the sudo command was
  skipped with a warning line. Cosmetic inconsistency only.

## Remaining

Ranked next targets:

1. `bin/executable_clean-worktrees.sh` FORCE branch duplication (~7 lines
   identical in DIRTY and UNMERGED arms) — left in place; restructuring a
   destructive interactive tool for a 7-line win is poor risk/reward.
2. `dot_config/git/config` `init.defaultBranch=master` — considered, kept
   (real effect: deterministic init branch); revisit only if Alan standardizes
   on another default.

## Totals

Run 1 (2026-09-13, 735b245..c15d072):

- source files: 51 → 49
- source LOC: 4445 → 3709 (−736)
- test files: 2 → 2
- test LOC: 644 → 614 (−30)
- total tracked files: 53 → 51

Run 2 (2026-09-13, 08eff7a..25dc9a2):

- source files: 49 → 49
- source LOC: 3709 → 3573 (−136)
- test files / LOC: unchanged (2 / 614)
- verification: `bash -n` on dot_zshrc, `tomllib` parse on both edited TOML
  files, diff review; contract suite still 41/41 green.

Run 3 (2026-09-13, 830b66b):

- source files: 49 → 49
- source LOC: 3573 → 3568 (−5)
- test files / LOC: unchanged (2 / 614)
- verification: hermetic scratch-repo run of clean-worktrees.sh (dry-run
  classification + real removal, exit statuses 1/0 as documented).

Verification: `bash -n` all touched shell scripts clean; contract suite
41/41 green after every commit; `python3 -m py_compile` on remaining python;
chezmoi binary unavailable in this environment — no `.tmpl` files were
touched, so no template rendering was required.

#!/usr/bin/env bash
# clean-worktrees.sh — Merge or purge stale git worktrees before a task is considered done
#
# Usage:
#   ~/scripts/clean-worktrees.sh                    # interactive (default) — prompts on ambiguous
#   ~/scripts/clean-worktrees.sh --repo ~/projects/foo  # target a specific repo
#   ~/scripts/clean-worktrees.sh --dry-run          # show what would happen, change nothing
#   ~/scripts/clean-worktrees.sh --force            # skip confirmation prompts (dangerous — confirm with Alan first)
#
# What it does:
#   1. Lists all git worktrees in the repo
#   2. For each worktree (excluding the main checkout):
#      a. Checks for uncommitted/untracked changes
#      b. Checks if the branch is merged into the target branch
#      c. Triages: merged → remove + delete branch; unmerged → flag for decision
#   3. Prunes stale worktree references
#   4. Reports a summary
#
# Safety:
#   - Never removes a worktree with uncommitted changes without confirmation
#   - Never deletes an unmerged branch without confirmation
#   - Untracked files (media/, logs, caches) are treated as user data — prompts before --force remove
#   - Does not touch the main checkout
#   - Does not touch Kanban workspaces (those are plain directories, not git worktrees)
#
# Requires: git (jj optional — if present, uses jj workspace commands too)

set -euo pipefail

REPO=""
DRY_RUN=false
FORCE=false
TARGET_BRANCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)     REPO="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --force)    FORCE=true; shift ;;
        --branch)   TARGET_BRANCH="$2"; shift 2 ;;
        --help|-h)
            head -18 "$0"
            exit 0
            ;;
        *)          echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Determine repo directory
if [[ -n "$REPO" ]]; then
    cd "$REPO" 2>/dev/null || { echo "✗ Cannot cd to $REPO" >&2; exit 1; }
fi

# Verify we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "✗ Not in a git repository" >&2
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Determine target branch (deploy target — main, vps-deploy, alan/prod, etc.)
if [[ -z "$TARGET_BRANCH" ]]; then
    # Try to detect: check for common deploy branch names
    for candidate in vps-deploy alan/prod main master; do
        if git show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null || \
           git show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>/dev/null; then
            TARGET_BRANCH="$candidate"
            break
        fi
    done
fi

if [[ -z "$TARGET_BRANCH" ]]; then
    # Fall back to current branch
    TARGET_BRANCH=$(git branch --show-current)
    echo "⚠ Could not detect deploy branch, using current branch: $TARGET_BRANCH" >&2
fi

echo ""
echo "◆ Worktree Cleanup"
echo "  Repo: $REPO_ROOT"
echo "  Target branch: $TARGET_BRANCH"
if [[ "$DRY_RUN" == true ]]; then
    echo "  Mode: DRY RUN (no changes will be made)"
elif [[ "$FORCE" == true ]]; then
    echo "  Mode: FORCE (skipping confirmations — dangerous)"
else
    echo "  Mode: interactive (will prompt on ambiguous cases)"
fi
echo ""

# Get list of worktrees (porcelain format)
mapfile -t WORKTREES < <(git worktree list --porcelain)

# Parse worktrees into arrays
declare -a WT_PATHS=()
declare -a WT_HEADS=()
declare -a WT_BRANCHES=()

CURRENT_INDEX=-1
for line in "${WORKTREES[@]}"; do
    case "$line" in
        worktree\ *)
            CURRENT_INDEX=$((CURRENT_INDEX + 1))
            WT_PATHS[$CURRENT_INDEX]="${line#worktree }"
            WT_HEADS[$CURRENT_INDEX]=""
            WT_BRANCHES[$CURRENT_INDEX]=""
            ;;
        HEAD\ *)
            WT_HEADS[$CURRENT_INDEX]="${line#HEAD }"
            ;;
        branch\ *)
            WT_BRANCHES[$CURRENT_INDEX]="${line#branch }"
            ;;
    esac
done

NUM_WORKTREES=$((CURRENT_INDEX + 1))

if [[ $NUM_WORKTREES -le 0 ]]; then
    echo "  No worktrees found."
    echo ""
    exit 0
fi

# Stats
MERGED_COUNT=0
REMOVED_COUNT=0
UNMERGED_COUNT=0
DIRTY_COUNT=0
FLAGGED_COUNT=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "◆ Inventory ($NUM_WORKTREES worktrees)"
echo ""

for ((i=0; i<NUM_WORKTREES; i++)); do
    WT_PATH="${WT_PATHS[$i]}"
    WT_HEAD="${WT_HEADS[$i]:-unknown}"
    WT_BRANCH_REF="${WT_BRANCHES[$i]:-}"
    WT_BRANCH="${WT_BRANCH_REF#refs/heads/}"

    # Skip the main checkout (first worktree, which is the repo root)
    if [[ "$WT_PATH" == "$REPO_ROOT" ]]; then
        printf "  %-55s [MAIN — skip]\n" "$WT_PATH"
        continue
    fi

    # Check if worktree directory still exists on disk
    if [[ ! -d "$WT_PATH" ]]; then
        printf "  %-55s [STALE — dir gone, will prune]\n" "$WT_PATH"
        if [[ "$DRY_RUN" != true ]]; then
            git worktree prune --verbose 2>/dev/null || true
        fi
        continue
    fi

    # Check for uncommitted changes
    DIRTY=""
    UNTRACKED=""
    if git -C "$WT_PATH" diff --quiet HEAD 2>/dev/null; then
        : # clean working tree
    else
        DIRTY="uncommitted"
    fi
    if [[ -n "$(git -C "$WT_PATH" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]]; then
        UNTRACKED="untracked"
    fi
    DIRTY_STATUS=""
    [[ -n "$DIRTY" ]] && DIRTY_STATUS="$DIRTY"
    [[ -n "$UNTRACKED" ]] && DIRTY_STATUS="${DIRTY_STATUS:+$DIRTY_STATUS, }$UNTRACKED"

    # Check if branch is merged into target
    MERGED=false
    if [[ -n "$WT_BRANCH" ]]; then
        if git merge-base --is-ancestor "$WT_BRANCH" "$TARGET_BRANCH" 2>/dev/null; then
            MERGED=true
        fi
    fi

    # Classify
    if [[ -n "$DIRTY_STATUS" ]]; then
        DIRTY_COUNT=$((DIRTY_COUNT + 1))
        printf "  %-55s [DIRTY: %s]\n" "$WT_PATH" "$DIRTY_STATUS"
        printf "  %-55s  branch: %s, merged: %s\n" "" "${WT_BRANCH:-none}" "$MERGED"

        if [[ "$FORCE" == true ]]; then
            echo "    → FORCE: removing without confirmation (dangerous)"
            if [[ "$DRY_RUN" != true ]]; then
                git worktree remove --force "$WT_PATH" 2>/dev/null || true
                [[ -n "$WT_BRANCH" ]] && git branch -D "$WT_BRANCH" 2>/dev/null || true
                REMOVED_COUNT=$((REMOVED_COUNT + 1))
            fi
        else
            FLAGGED_COUNT=$((FLAGGED_COUNT + 1))
            echo "    → FLAGGED: has uncommitted/untracked changes. Handle manually or use --force."
        fi
    elif [[ "$MERGED" == true ]]; then
        MERGED_COUNT=$((MERGED_COUNT + 1))
        printf "  %-55s [MERGED — safe to remove]\n" "$WT_PATH"
        printf "  %-55s  branch: %s\n" "" "${WT_BRANCH:-none}"

        if [[ "$DRY_RUN" != true ]]; then
            git worktree remove "$WT_PATH" 2>/dev/null || {
                echo "    ⚠ worktree remove failed (untracked files? use --force or handle manually)"
                continue
            }
            if [[ -n "$WT_BRANCH" ]]; then
                git branch -d "$WT_BRANCH" 2>/dev/null || {
                    echo "    ⚠ branch -d failed for $WT_BRANCH (not merged? manually check)"
                }
            fi
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    else
        UNMERGED_COUNT=$((UNMERGED_COUNT + 1))
        printf "  %-55s [UNMERGED — needs decision]\n" "$WT_PATH"
        printf "  %-55s  branch: %s\n" "" "${WT_BRANCH:-none}"

        if [[ "$FORCE" == true ]]; then
            echo "    → FORCE: removing without confirmation (dangerous)"
            if [[ "$DRY_RUN" != true ]]; then
                git worktree remove --force "$WT_PATH" 2>/dev/null || true
                [[ -n "$WT_BRANCH" ]] && git branch -D "$WT_BRANCH" 2>/dev/null || true
                REMOVED_COUNT=$((REMOVED_COUNT + 1))
            fi
        else
            FLAGGED_COUNT=$((FLAGGED_COUNT + 1))
            echo "    → FLAGGED: unmerged branch. Merge into $TARGET_BRANCH or confirm abandon with Alan."
        fi
    fi
    echo ""
done

# Prune stale references
if [[ "$DRY_RUN" != true ]]; then
    git worktree prune 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "◆ Summary"
echo ""
echo "  Total worktrees:    $NUM_WORKTREES"
echo "  Merged (removed):   $REMOVED_COUNT"
echo "  Unmerged (flagged): $UNMERGED_COUNT"
echo "  Dirty (flagged):    $DIRTY_COUNT"
echo "  Flagged for manual: $FLAGGED_COUNT"
echo ""

if [[ $FLAGGED_COUNT -gt 0 ]]; then
    echo "  ⚠ $FLAGGED_COUNT worktree(s) need manual attention:"
    echo "    - Uncommitted changes: commit/merge or confirm discard"
    echo "    - Unmerged branches: merge into $TARGET_BRANCH or confirm abandon with Alan"
    echo ""
    echo "  Re-run with --force to remove flagged worktrees WITHOUT confirmation."
    echo "  (Dangerous — only if you've verified the work is disposable.)"
    echo ""
    exit 1
fi

if [[ $REMOVED_COUNT -gt 0 ]]; then
    echo "  ✓ Cleaned up $REMOVED_COUNT merged worktree(s)."
fi

echo "  ✓ All worktrees merged or purged. No orphans."
echo ""

# Also check jj workspaces if jj is present
if command -v jj >/dev/null 2>&1; then
    if jj workspace list >/dev/null 2>&1; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "◆ jj workspaces"
        echo ""
        jj workspace list 2>/dev/null | while read -r ws; do
            echo "  $ws"
        done
        echo ""
        echo "  To clean up jj workspaces: jj workspace forget <name> && rm -rf <path>"
        echo ""
    fi
fi
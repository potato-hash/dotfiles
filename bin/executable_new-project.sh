#!/usr/bin/env bash
# new-project.sh — Initialize a new project with colocated jj, private GitHub repo, and AGENTS.md
#
# Usage:
#   ~/scripts/new-project.sh <name>              # private repo (default)
#   ~/scripts/new-project.sh <name> --public     # public repo (confirm with Alan first)
#   ~/scripts/new-project.sh <name> --no-gh      # skip GitHub creation (local only — not recommended)
#
# Creates:
#   ~/projects/<name>/ with colocated jj+git, AGENTS.md, .gitignore, README.md,
#   private GitHub repo under potato-hash/, initial commit pushed to origin/main
#
# Requires: jj, gh (authenticated), git
# Templates: ~/.hermes/templates/new-project/

set -euo pipefail

NAME=""
VISIBILITY="private"
CREATE_GH=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --public)   VISIBILITY="public"; shift ;;
        --no-gh)    CREATE_GH=false; shift ;;
        --help|-h)
            head -13 "$0"
            exit 0
            ;;
        *)          NAME="$1"; shift ;;
    esac
done

if [[ -z "$NAME" ]]; then
    echo "Usage: $(basename "$0") <name> [--public|--no-gh]" >&2
    exit 1
fi

PROJECTS_DIR="$HOME/projects"
PROJECT_DIR="$PROJECTS_DIR/$NAME"
TEMPLATE_DIR="$HOME/.hermes/templates/new-project"

# --- Pre-flight checks ---

if [[ -d "$PROJECT_DIR" ]]; then
    echo "✗ Directory already exists: $PROJECT_DIR" >&2
    exit 1
fi

for cmd in jj git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "✗ $cmd is not installed" >&2
        exit 1
    fi
done

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "✗ Template directory missing: $TEMPLATE_DIR" >&2
    exit 1
fi

if [[ "$CREATE_GH" == true ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "✗ gh CLI is not installed (required for GitHub repo creation)" >&2
        echo "  Install: brew install gh && gh auth login" >&2
        echo "  Or use --no-gh for local-only (not recommended — no remote backup)" >&2
        exit 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "✗ gh is not authenticated. Run: gh auth login" >&2
        echo "  Or use --no-gh for local-only (not recommended — no remote backup)" >&2
        exit 1
    fi
fi

if [[ "$VISIBILITY" == "public" ]]; then
    echo "⚠  Creating a PUBLIC repo. This is irreversible — the repo will be visible to everyone."
    echo "   Press Ctrl+C within 5 seconds to cancel..."
    sleep 5
fi

# --- Execute ---

echo ""
echo "◆ Creating project: $NAME ($VISIBILITY)"
echo "  Directory: $PROJECT_DIR"
echo ""

# 1. Create directory
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 2. Copy templates
cp "$TEMPLATE_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
cp "$TEMPLATE_DIR/.gitignore" "$PROJECT_DIR/.gitignore"
cp "$TEMPLATE_DIR/README.md" "$PROJECT_DIR/README.md"

# 3. Personalize AGENTS.md and README with project name
sed -i "s/__PROJECT_NAME__/$NAME/g" "$PROJECT_DIR/AGENTS.md"
sed -i "s/__PROJECT_NAME__/$NAME/g" "$PROJECT_DIR/README.md"

echo "  ✓ Templates copied and personalized"

# 4. Initialize colocated jj+git
jj git init --colocate >/dev/null 2>&1
echo "  ✓ jj git init --colocate"

# 5. Describe the initial change (jj auto-commits the working copy)
jj describe -m "bootstrap $NAME" >/dev/null 2>&1
echo "  ✓ Initial commit: \"bootstrap $NAME\""

# 6. Create GitHub repo and push (or skip with warning)
if [[ "$CREATE_GH" == true ]]; then
    gh repo create "potato-hash/$NAME" "--$VISIBILITY" --source=. --push >/dev/null 2>&1
    echo "  ✓ GitHub repo created: potato-hash/$NAME ($VISIBILITY)"

    # 7. Set up bookmark tracking
    jj bookmark track main --remote=origin >/dev/null 2>&1
    echo "  ✓ Bookmark tracking: main → origin/main"
else
    echo ""
    echo "  ⚠  --no-gh: No GitHub remote created."
    echo "     This project has no remote backup — it will be lost on hardware failure."
    echo "     Create a remote later: gh repo create potato-hash/$NAME --private --source=. --push"
fi

# --- Verify ---

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "◆ Verification"
echo ""

# jj status
if jj status >/dev/null 2>&1; then
    echo "  ✓ jj status: OK"
else
    echo "  ✗ jj status: FAILED" >&2
    exit 1
fi

# Bookmark tracking
if jj bookmark list 2>/dev/null | grep -q "main"; then
    echo "  ✓ jj bookmark: main tracked"
else
    echo "  ⚠ jj bookmark: main not found (may need jj bookmark track main --remote=origin)"
fi

# Remote
if [[ "$CREATE_GH" == true ]]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$REMOTE_URL" ]]; then
        echo "  ✓ git remote: $REMOTE_URL"
    else
        echo "  ✗ git remote: origin not set" >&2
        exit 1
    fi
fi

# AGENTS.md
if [[ -f "$PROJECT_DIR/AGENTS.md" ]]; then
    if grep -q "engineering-handbook" "$PROJECT_DIR/AGENTS.md"; then
        echo "  ✓ AGENTS.md: delegation policy pointer present"
    else
        echo "  ⚠ AGENTS.md: delegation policy pointer missing"
    fi
else
    echo "  ✗ AGENTS.md: file missing" >&2
    exit 1
fi

# .gitignore
if [[ -f "$PROJECT_DIR/.gitignore" ]]; then
    echo "  ✓ .gitignore: present"
else
    echo "  ⚠ .gitignore: missing"
fi

echo ""
echo "◆ Done. Project ready at: $PROJECT_DIR"
if [[ "$CREATE_GH" == true ]]; then
    echo "  GitHub: https://github.com/potato-hash/$NAME"
fi
echo ""
echo "  Next: cd $PROJECT_DIR && start coding"
echo ""
#!/bin/bash
# Helper script to clone/mirror a git repository for cgit
# Usage: ./clone-repo.sh <git-url> [repo-name] [description] [owner]
# Supports: GitHub, GitLab, Codeberg, or any git service

set -e

GIT_URL="$1"
REPO_NAME="${2:-}"
REPO_DESC="${3:-Mirrored repository}"
REPO_OWNER="${4:-${CGIT_OWNER:-}}"
REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"
CACHE_DIR="${CACHE_DIR:-/opt/cgit/data/cache}"
CGIT_HOST="${CGIT_HOST:-localhost}"
CGIT_PORT="${CGIT_PORT:-2222}"

function clear_cache() {
    if [ -d "$CACHE_DIR" ]; then
        echo "Clearing cgit cache..."
        rm -rf "${CACHE_DIR:?}"/*
        echo "Cache cleared."
    fi
}

if [ -z "$GIT_URL" ]; then
    echo "Usage: $0 <git-url> [repo-name] [description] [owner]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/repo.git"
    echo "  $0 https://gitlab.com/user/repo.git"
    echo "  $0 https://codeberg.org/user/repo.git"
    echo "  $0 https://github.com/user/repo.git repo-name 'Custom Description' 'Owner Name <email>'"
    echo ""
    echo "Supported protocols: https://, git://, ssh://"
    echo "Note: Repositories are created in /opt/cgit/data/repositories by default"
    exit 1
fi

# Extract repository name from URL if not provided
if [ -z "$REPO_NAME" ]; then
    REPO_NAME=$(basename "$GIT_URL" .git)
    echo "Auto-detected repository name: $REPO_NAME"
fi

# Validate repository name (no spaces, no special chars except - and _)
if [[ ! "$REPO_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Repository name can only contain letters, numbers, hyphens, and underscores"
    exit 1
fi

# Remove .git suffix if provided
REPO_NAME="${REPO_NAME%.git}"

REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

if [ -d "$REPO_PATH" ]; then
    echo "Error: Repository already exists at $REPO_PATH"
    exit 1
fi

echo "Cloning repository from: $GIT_URL"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git clone --bare --mirror "$GIT_URL" "${REPO_NAME}.git"

cd "$REPO_PATH"

# Configure cgit metadata
echo "Configuring cgit metadata..."
git config --local cgit.name "$REPO_NAME"
git config --local cgit.desc "$REPO_DESC"

if [ -n "$REPO_OWNER" ]; then
    git config --local cgit.owner "$REPO_OWNER"
fi

# Detect default branch from refs
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git config --local cgit.defbranch "$DEFAULT_BRANCH"

# Enable README rendering if present (note: colon prefix required for cgit)
git config --local cgit.readme ":README.md"

# Add clone URL metadata (use local server URLs instead of source)
# Generate multiple clone URLs: git://, https://, and ssh://
CLONE_URLS="git://${CGIT_HOST}/${REPO_NAME}.git https://${CGIT_HOST}/${REPO_NAME}.git ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
git config --local cgit.clone-url "$CLONE_URLS"

# Clear cache so repository appears immediately
clear_cache

echo ""
echo "Repository mirrored successfully!"
echo ""
echo "Repository path: $REPO_PATH"
echo "Display name:    $REPO_NAME"
echo "Description:     $REPO_DESC"
echo "Default branch:  $DEFAULT_BRANCH"
echo "Source URL:      $GIT_URL"
echo "Clone URLs:"
echo "  git://$CGIT_HOST/$REPO_NAME.git"
echo "  https://$CGIT_HOST/$REPO_NAME.git"
echo "  ssh://git@$CGIT_HOST:$CGIT_PORT/$REPO_NAME.git"
if [ -n "$REPO_OWNER" ]; then
    echo "Owner:           $REPO_OWNER"
fi
echo ""
echo "To update this mirror:"
echo "  repo update ${REPO_NAME}"
echo ""
echo "Or use this repository:"
echo "  git clone ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
echo ""

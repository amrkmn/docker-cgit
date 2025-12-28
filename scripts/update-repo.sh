#!/bin/bash
# Helper script to update a mirrored git repository from cgit
# Usage: ./update-repo.sh <repo-name>

set -e

REPO_NAME="$1"
REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"
CACHE_DIR="${CACHE_DIR:-/opt/cgit/data/cache}"

function clear_cache() {
    if [ -d "$CACHE_DIR" ]; then
        echo "Clearing cgit cache..."
        rm -rf "${CACHE_DIR:?}"/*
        echo "Cache cleared."
    fi
}

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name>"
    echo ""
    echo "Example:"
    echo "  $0 my-project"
    echo ""
    echo "Note: This updates mirrored repositories by fetching latest changes from their remote"
    exit 1
fi

# Validate repository name (no spaces, no special chars except - and _)
if [[ ! "$REPO_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Repository name can only contain letters, numbers, hyphens, and underscores"
    exit 1
fi

# Remove .git suffix if provided
REPO_NAME="${REPO_NAME%.git}"

REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

if [ ! -d "$REPO_PATH" ]; then
    echo "Error: Repository does not exist at $REPO_PATH"
    exit 1
fi

echo "Updating repository: $REPO_NAME"

cd "$REPO_PATH"

# Check if repository has a remote configured
if ! git remote | grep -q .; then
    echo "Error: No remote configured for this repository"
    exit 1
fi

# Get the remote name (usually 'origin')
REMOTE_NAME=$(git remote | head -n 1)
REMOTE_URL=$(git remote get-url "$REMOTE_NAME")

echo ""
echo "Fetching updates from $REMOTE_NAME ($REMOTE_URL)..."
git remote update "$REMOTE_NAME" --prune

echo ""
echo "Repository updated successfully!"
echo ""

# Clear cache so updates are reflected immediately
clear_cache

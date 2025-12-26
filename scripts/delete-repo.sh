#!/bin/bash
# Helper script to delete a git repository from cgit
# Usage: ./delete-repo.sh <repo-name>

set -e

REPO_NAME="$1"
REPO_DIR="${REPO_DIR:-/opt/cgit/repositories}"
CACHE_DIR="${CACHE_DIR:-/opt/cgit/cache}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name>"
    echo ""
    echo "Example:"
    echo "  $0 my-project"
    echo ""
    echo "Note: This permanently deletes the repository and all its data"
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

echo "Deleting repository: $REPO_PATH"
echo "This will permanently delete all repository data!"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deletion cancelled."
    exit 0
fi

rm -rf "$REPO_PATH"

# Clear cache so deletion is reflected immediately
if [ -d "$CACHE_DIR" ]; then
    echo "Clearing cgit cache..."
    rm -rf "${CACHE_DIR:?}"/*
    echo "Cache cleared."
fi

echo ""
echo "Repository deleted successfully!"

#!/bin/bash
# Helper script to delete a git repository from cgit
# Usage: ./delete-repo.sh <repo-name> [--yes]

set -e

REPO_NAME=""
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            if [ -z "$REPO_NAME" ]; then
                REPO_NAME="$1"
            else
                echo "Error: Unknown argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

REPO_DIR="${REPO_DIR:-/opt/cgit/repositories}"
CACHE_DIR="${CACHE_DIR:-/opt/cgit/cache}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name> [--yes]"
    echo ""
    echo "Options:"
    echo "  -y, --yes    Skip confirmation prompt"
    echo ""
    echo "Example:"
    echo "  $0 my-project"
    echo "  $0 my-project --yes"
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

if [ "$SKIP_CONFIRM" = false ]; then
    # Check if running in an interactive terminal
    if [ -t 0 ]; then
        echo ""
        read -p "Are you sure? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo "Deletion cancelled."
            exit 0
        fi
    else
        echo ""
        echo "Error: Not running in interactive mode."
        echo "To delete without confirmation, use: $0 $REPO_NAME --yes"
        exit 1
    fi
fi

echo ""
echo "Proceeding with deletion..."

rm -rf "$REPO_PATH"

# Clear cache so deletion is reflected immediately
if [ -d "$CACHE_DIR" ]; then
    echo "Clearing cgit cache..."
    rm -rf "${CACHE_DIR:?}"/*
    echo "Cache cleared."
fi

echo ""
echo "Repository deleted successfully!"

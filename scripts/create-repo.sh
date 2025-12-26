#!/bin/bash
# Helper script to initialize a new bare git repository for cgit
# Usage: ./create-repo.sh <repo-name> [description] [owner]

set -e

REPO_NAME="$1"
REPO_DESC="${2:-A git repository}"
REPO_OWNER="${3:-$(git config user.name 2>/dev/null || echo 'Unknown User')} <$(git config user.email 2>/dev/null || echo 'unknown@example.com')>"
REPO_DIR="${REPO_DIR:-/opt/cgit/repositories}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name> [description] [owner]"
    echo ""
    echo "Examples:"
    echo "  $0 my-project"
    echo "  $0 my-project 'My awesome project'"
    echo "  $0 my-project 'My awesome project' 'John Doe <john@example.com>'"
    echo ""
    echo "Note: Repositories are created in /opt/cgit/repositories by default"
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

if [ -d "$REPO_PATH" ]; then
    echo "Error: Repository already exists at $REPO_PATH"
    exit 1
fi

echo "Creating bare repository: $REPO_PATH"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init --bare "${REPO_NAME}.git"

cd "$REPO_PATH"

echo "Configuring cgit metadata..."
git config --local cgit.name "$REPO_NAME"
git config --local cgit.desc "$REPO_DESC"

if [ -n "$REPO_OWNER" ]; then
    git config --local cgit.owner "$REPO_OWNER"
fi

# Set default branch to main
git config --local cgit.defbranch "main"

# Enable README rendering if present
git config --local cgit.readme "README.md"

# Optional: set a section/category
# git config --local cgit.section "Personal Projects"

echo ""
echo "Repository created successfully!"
echo ""
echo "Repository path: $REPO_PATH"
echo "Display name:    $REPO_NAME"
echo "Description:     $REPO_DESC"
echo "Owner:           $REPO_OWNER"
echo ""
echo "To use this repository:"
echo "  git clone ssh://git@your-host:2222/${REPO_NAME}.git"
echo ""
echo "Or add as remote to existing repository:"
echo "  git remote add origin ssh://git@your-host:2222/${REPO_NAME}.git"
echo "  git push -u origin main"
echo ""

#!/bin/bash
# Helper script to list all git repositories in cgit
# Usage: ./list-repo.sh

set -e

REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"
CGIT_HOST="${CGIT_HOST:-localhost}"
CGIT_PORT="${CGIT_PORT:-2222}"

if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Repository directory does not exist: $REPO_DIR"
    exit 1
fi

# Find all .git directories
REPOS=$(find "$REPO_DIR" -maxdepth 1 -type d -name "*.git" | sort)

if [ -z "$REPOS" ]; then
    echo "No repositories found in $REPO_DIR"
    exit 0
fi

echo "Found $(echo "$REPOS" | wc -l) repository/repositories:"
echo ""

for REPO_PATH in $REPOS; do
    REPO_NAME=$(basename "$REPO_PATH" .git)
    
    # Get cgit metadata
    NAME=$(git -C "$REPO_PATH" config --local cgit.name 2>/dev/null || echo "$REPO_NAME")
    DESC=$(git -C "$REPO_PATH" config --local cgit.desc 2>/dev/null || echo "No description")
    OWNER=$(git -C "$REPO_PATH" config --local cgit.owner 2>/dev/null || echo "Unknown")
    DEFAULT_BRANCH=$(git -C "$REPO_PATH" config --local cgit.defbranch 2>/dev/null || echo "main")
    
    # Get last commit date
    LAST_COMMIT=$(git -C "$REPO_PATH" log -1 --format=%cd --date=short 2>/dev/null || echo "Never")
    
    # Get number of branches
    BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | wc -l)
    
    echo "Name:            $NAME"
    echo "Path:            $REPO_PATH"
    echo "Description:     $DESC"
    echo "Owner:           $OWNER"
    echo "Default branch:  $DEFAULT_BRANCH"
    echo "Branches:        $BRANCHES"
    echo "Last commit:     $LAST_COMMIT"
    echo "Clone URL:       ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
    echo ""
done

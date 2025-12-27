#!/bin/sh
# Wrapper script that rewrites git paths to /opt/cgit/data/repositories
# Allows: git clone ssh://git@host:port/repo.git
# Instead of: git clone ssh://git@host:port/opt/cgit/data/repositories/repo.git

REPO_BASE="/opt/cgit/data/repositories"

if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
    echo "Interactive shell access is disabled."
    exit 1
fi

# SSH_ORIGINAL_COMMAND is like: git-upload-pack '/test-repo.git'
# Extract command and path
CMD=$(echo "$SSH_ORIGINAL_COMMAND" | cut -d' ' -f1)
# Get path, strip quotes
PATH_ARG=$(echo "$SSH_ORIGINAL_COMMAND" | cut -d"'" -f2)

# Prepend repository base path
FULL_PATH="${REPO_BASE}${PATH_ARG}"

exec $CMD "$FULL_PATH"

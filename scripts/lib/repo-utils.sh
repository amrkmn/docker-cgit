#!/bin/bash
# Repository utilities library
# Shared utility functions for repository management

function clear_cache() {
    if [ -d "$CACHE_DIR" ]; then
        echo "Clearing cgit cache..."
        rm -rf "${CACHE_DIR:?}"/*
        echo "Cache cleared."
    fi
}

function validate_repo_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Repository name can only contain letters, numbers, hyphens, and underscores"
        exit 1
    fi
}

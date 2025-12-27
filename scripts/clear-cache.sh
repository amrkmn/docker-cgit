#!/bin/bash
set -e

CACHE_DIR="/opt/cgit/data/cache"

echo "Clearing cgit cache at ${CACHE_DIR}..."

if [ -d "$CACHE_DIR" ]; then
    rm -rf "${CACHE_DIR:?}"/*
    echo "Cache cleared successfully."
else
    echo "Cache directory does not exist: $CACHE_DIR"
fi

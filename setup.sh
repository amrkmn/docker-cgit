#!/bin/bash
# Initial setup script for docker-cgit
# Creates necessary directories and copies config files if they don't exist

set -e

echo "Setting up docker-cgit..."

# Create data directories
mkdir -p data/repositories
mkdir -p data/ssh
mkdir -p data/cache

# Copy cgitrc if it doesn't exist
if [ ! -f data/cgitrc ]; then
    echo "Creating data/cgitrc from config/cgitrc..."
    cp config/cgitrc data/cgitrc
    echo "✓ data/cgitrc created"
else
    echo "✓ data/cgitrc already exists, skipping"
fi

# Ensure proper permissions
chmod 700 data/ssh
chmod 600 data/ssh/authorized_keys 2>/dev/null || true

echo ""
echo "Setup complete!"
echo "You can now run: docker compose up -d"
echo ""
echo "Configuration files you can edit:"
echo "  - data/cgitrc    (cgit configuration)"
echo "  - data/ssh/authorized_keys (SSH public keys)"

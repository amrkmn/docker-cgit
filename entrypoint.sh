#!/bin/sh
# Entrypoint wrapper - auto-generates user config on first run
# Then runs s6-overlay init

DATA_CGITRC="/opt/cgit/data/cgitrc"

# Create user config from defaults if it doesn't exist
DATA_CGITRC="/opt/cgit/data/cgitrc"

# Create user config from defaults if it doesn't exist
if [ ! -f "$DATA_CGITRC" ]; then
    echo "[cgit-init] Creating user config at $DATA_CGITRC..."
    mkdir -p /opt/cgit/data
    
    # Create user config with updated paths (/opt/cgit/data/*)
    cat > "$DATA_CGITRC" << 'EOF'
# User cgit configuration
# Edit this file to customize cgit settings
# Defaults from /opt/cgit/cgitrc are automatically included

# Example overrides:
# root-title=My Git Server
# root-desc=My private repositories
# css=/cgit-dark.css

# Add your custom repositories here:
# repo.url=repo.git
# repo.path=/opt/cgit/data/repositories/repo.git
# repo.desc=My repository
# repo.owner=Your Name

# Important: scan-path points to /opt/cgit/data/repositories/
EOF
    
    echo "[cgit-init] ✓ Created $DATA_CGITRC"
    echo "[cgit-init] Edit this file in ./data/cgitrc to customize cgit"
else
    echo "[cgit-init] Using existing $DATA_CGITRC"
fi

# Run s6-overlay init
exec /init "$@"

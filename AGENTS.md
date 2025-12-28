# AGENTS.md

This file provides guidance for agentic coding agents working with the docker-cgit repository.

## Build & Development Commands

### Docker Commands
```bash
# Build and start
docker compose build                          # Build image locally
docker compose up -d                          # Start container in detached mode
docker compose logs -f                        # View live logs
docker compose logs -f cgit                   # View logs for specific service

# Development & debugging
docker compose exec cgit sh                   # Shell into running container
docker build --target=builder -t cgit-builder .  # Build specific stage for debugging
docker compose down                           # Stop and remove containers
docker compose restart cgit                   # Restart container

# Health checks
docker compose ps                             # Check container status
docker compose exec cgit wget --spider http://localhost:80/
docker compose exec cgit s6-rc -a list        # List all s6-rc services
```

### Lint/Validation
```bash
# No automated linting configured. Manual validation:
docker compose exec cgit nginx -t             # Validate nginx config
docker compose exec cgit python3 -m py_compile /opt/cgit/bin/mirror-sync-daemon.py
shellcheck scripts/repo                       # Run shellcheck locally (if installed)
```

### Repository Management
All repository operations use the unified `repo` command (scripts/repo:1).

```bash
# Core operations
docker compose exec cgit repo create test-repo "Description" "Owner <email>"
docker compose exec cgit repo clone https://github.com/user/repo.git
docker compose exec cgit repo clone https://github.com/user/repo.git --mirror  # Enable auto-sync
docker compose exec cgit repo list           # List all repositories with metadata
docker compose exec cgit repo update test-repo  # Update mirrored repository

# Mirror management
docker compose exec cgit repo mirror enable test-repo  # Enable auto-sync
docker compose exec cgit repo mirror disable test-repo # Disable auto-sync
docker compose exec cgit repo mirror list    # List all mirrors
docker compose exec cgit repo mirror status test-repo  # Show mirror status
docker compose exec cgit repo mirror sync test-repo    # Manual sync now
docker compose exec cgit repo mirror logs    # View sync logs

# Destructive operations
docker compose exec cgit repo delete test-repo --yes  # Skip confirmation
docker compose exec cgit repo clear-cache     # Clear cgit cache after changes
```

### Testing
No automated test suite exists. Manual testing workflow:

```bash
# Test single component (e.g., mirror sync daemon)
docker compose exec cgit python3 /opt/cgit/bin/mirror-sync-daemon.py  # Run daemon directly
docker compose exec cgit /opt/cgit/bin/repo mirror list                # Test CLI command

# Test Git protocols
ssh -p 2222 git@localhost                     # Verify SSH access
git clone ssh://git@localhost:2222/test-repo.git  # Test SSH clone (read-write)
git clone http://localhost:8081/test-repo.git     # Test HTTP clone (read-only)
git clone git://localhost:9418/test-repo.git      # Test git:// protocol (read-only)

# Test mirror auto-sync
docker compose exec cgit repo clone https://github.com/torvalds/linux.git --mirror
docker compose exec cgit repo mirror status linux  # Check sync status
docker compose exec cgit repo mirror logs         # View sync logs

# Test services
docker compose exec cgit s6-rc -a list        # Verify all services running
docker compose exec cgit ps aux | grep mirror # Check mirror-sync daemon
docker compose exec cgit /opt/cgit/app/cgit.cgi  # Test cgit.cgi directly
```

## Code Style Guidelines

### Shell Scripts (Bash)
- **Shebang & safety**: `#!/bin/bash` with `set -e` for error handling
- **Quoting**: Always quote variables: `"$VAR"` not `$VAR`
- **Variables**: UPPER_CASE for env/global vars, lower_case for local vars
- **Functions**: Use `function_name()` format (no `function` keyword), declare `local` vars
- **Indentation**: 4 spaces (no tabs)
- **Validation**: Validate inputs, provide usage help, exit with non-zero on errors
- **Consolidation**: Group related functionality (see scripts/repo:320 for unified command pattern)

```bash
#!/bin/bash
set -e

REPO_NAME="$1"
REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"

validate_repo_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Error: Invalid name"; exit 1; }
}
```

### Dockerfile
- **Multi-stage builds**: Separate builder and runtime stages (Dockerfile:6, Dockerfile:28)
- **Layering**: Group RUN commands with `&&`, minimize layers
- **Versioning**: Use ARG for build versions, ENV for runtime config
- **Order**: System packages → cleanup → user creation → config files → permissions

### Docker Compose
- Use environment variables for configuration (docker-compose.yml:12)
- Define restart policies (`restart: unless-stopped`)
- Use descriptive service names and proper volume mappings
- Keep configurations user-customizable via env vars

### s6-rc Services
- **Longrun services**: Use `#!/command/execlineb -P` (s6-rc/nginx/run:1)
- **Dependencies**: Define via `dependencies.d/` directories
- **Type files**: `longrun`, `oneshot`, or `bundle` in `type` file
- **Permissions**: Ensure scripts are executable (755)

### Python Scripts
- **Shebang**: `#!/usr/bin/env python3` for portability
- **Style**: PEP 8 (4-space indentation, snake_case for functions/variables)
- **Import order**: stdlib → third-party → local (see scripts/mirror-sync-daemon.py:18-29)
  ```python
  import sys
  import os
  from datetime import datetime
  
  sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
  from croniter import croniter
  ```
- **Docstrings**: Module-level and class-level docstrings (triple quotes)
- **Type hints**: Not required but encouraged for complex functions
- **Classes**: PascalCase naming (e.g., `MirrorConfig`, `SimpleLogger`)
- **Constants**: UPPER_CASE at module level (e.g., `CONFIG_FILE`, `MAX_LOG_SIZE`)
- **Error handling**: Try/except with specific exceptions, log errors to stderr
- **Path handling**: Use `os.path.join()` for cross-platform compatibility
- **Environment variables**: Use `os.getenv()` with defaults for configuration

### Configuration Files
- **cgitrc**: Follow upstream format, use absolute paths in container contexts
- **Separate concerns**: System defaults in /opt/cgit/cgitrc, user overrides in /opt/cgit/data/cgitrc
- **Comments**: Add comments for non-obvious settings
- **Git metadata**: Use `git config --local cgit.*` for repository metadata (scripts/repo:61)
  - Standard fields: name, desc, owner, section, defbranch, readme
  - README files: Use colon prefix (`:README.md`) for in-tree files

### Naming Conventions
- **Files**: kebab-case for scripts, camelCase for configs
- **Directories**: kebab-case
- **Variables**: UPPER_CASE for env vars, lower_case for locals
- **Functions**: snake_case with descriptive names

### Error Handling & Security
- **Shell scripts**: Use `set -e`, validate inputs, meaningful error messages
- **Python scripts**: Use try/except blocks, log to stderr for errors
- **File operations**: Conditional checks before destructive operations
  ```bash
  if [ -d "$CACHE_DIR" ]; then
      rm -rf "${CACHE_DIR:?}"/*  # Use :? to prevent empty var expansion
  fi
  ```
- **Permissions**: Scripts 755, configs 644, secrets 600, sensitive dirs 700
- **Security**: Never log secrets, use read-only mounts, minimal user permissions
- **Input validation**: Validate external inputs (scripts/repo:22 validates repo names)
- **Graceful shutdown**: Handle SIGTERM/SIGINT in long-running processes
- **JSON handling**: Use try/except for `json.load()` and provide defaults

## Repository Structure

```
docker-cgit/
├── Dockerfile              # Multi-stage build (builder → runtime)
├── docker-compose.yml      # Service orchestration & env config
├── entrypoint.sh           # Auto-generates /opt/cgit/data/cgitrc on first run
├── config/                 # Default configurations
│   ├── cgitrc             # System cgit defaults (included by user config)
│   ├── filters/           # Syntax highlighting & markdown rendering
│   ├── nginx/             # Web server reverse proxy config
│   └── sshd_config        # SSH server for git+ssh://
├── scripts/                # Container scripts (in PATH)
│   ├── repo               # Unified repository management CLI
│   ├── mirror-manager.py  # Mirror configuration management
│   ├── mirror-logger.py   # Mirror sync logging with rotation
│   ├── mirror-sync-daemon.py  # Background sync service
│   └── lib/               # Bundled Python libraries (croniter, pytz, dateutil)
└── s6-rc/                 # s6-overlay service definitions
    ├── prepare-services   # Oneshot: SSH key setup
    ├── nginx              # Longrun: Web server
    ├── fcgiwrap           # Longrun: FastCGI wrapper for cgit.cgi
    ├── sshd               # Longrun: SSH server
    ├── git-daemon         # Longrun: git:// protocol server
    └── mirror-sync        # Longrun: Background mirror sync daemon
```

## CI/CD Pipeline

- **Multi-arch builds**: amd64, arm64 via GitHub Actions (matrix strategy)
- **Build system**: Docker Buildx with QEMU for cross-platform
- **Registry**: GitHub Container Registry (ghcr.io)
- **Caching**: GitHub Actions cache + registry cache
- **Tagging**: Semantic versioning (v*.*.*, latest on main branch)

## Key Implementation Patterns

### Idempotent Operations
Commands should be idempotent - safe to run multiple times:
```bash
# Good: Check before creating
if [ ! -d "$REPO_DIR/$repo_name.git" ]; then
    git init --bare "$REPO_DIR/$repo_name.git"
fi

# Good: Use os.makedirs with exist_ok=True
os.makedirs(LOG_DIR, exist_ok=True)
```

### Configuration Management
- **Environment variables**: Default values with `${VAR:-default}` in bash
- **JSON configs**: Store structured data in `/opt/cgit/data/` for persistence
- **Git configs**: Use `git config --local cgit.*` for repository metadata

### Background Services
- Run with low priority: `nice -n 19` to avoid impacting web performance
- Implement graceful shutdown handlers for SIGTERM/SIGINT
- Use `ThreadPoolExecutor` for parallel operations with concurrency limits
- Log to both file and stdout for container compatibility

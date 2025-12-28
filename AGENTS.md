# AGENTS.md

Guidance for agentic coding agents working with the docker-cgit repository.

## Build & Development Commands

### Docker Operations
```bash
# Build and run
docker compose build && docker compose up -d
docker compose logs -f cgit              # View logs
docker compose exec cgit sh              # Shell into container
docker compose restart cgit              # Restart after changes

# Validation
docker compose exec cgit nginx -t                              # Validate nginx
docker compose exec cgit python3 -m py_compile /opt/cgit/bin/*.py
shellcheck scripts/repo scripts/lib/*.sh                      # Local shellcheck
```

### Repository Management (via `repo` command)
```bash
# Core operations
docker compose exec cgit repo create <name> "[desc]" "[owner]"
docker compose exec cgit repo clone <url> [--mirror]
docker compose exec cgit repo list
docker compose exec cgit repo delete <name> --yes

# Mirror auto-sync
docker compose exec cgit repo mirror enable <name> [--schedule "0 */6 * * *"] [--timeout 600]
docker compose exec cgit repo mirror sync <name>
docker compose exec cgit repo mirror status <name>
docker compose exec cgit repo mirror logs
```

### Testing
No automated tests. Manual testing workflow:
```bash
# Test services
docker compose exec cgit s6-rc -a list
git clone ssh://git@localhost:2222/test-repo.git     # SSH (read-write)
git clone http://localhost:8081/test-repo.git        # HTTP (read-only)
```

## Code Style Guidelines

### Shell Scripts (Bash)
- **Header**: `#!/bin/bash` with `set -e`
- **Variables**: UPPER_CASE for env/global, lower_case for local
- **Functions**: `function_name()` format, use `local` for variables
- **Quoting**: Always quote variables: `"$VAR"`
- **Indentation**: 4 spaces, no tabs
- **Modularity**: Split large files into `scripts/lib/*.sh` libraries
- **Sourcing**: `source "$SCRIPT_DIR/lib/module.sh"`
- **Validation**: Check inputs, provide usage help, exit non-zero on errors

Example:
```bash
#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"

validate_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Error: Invalid"; exit 1; }
}
```

### Python Scripts
- **Header**: `#!/usr/bin/env python3`
- **Style**: PEP 8 (4-space indent, snake_case)
- **Import order**: stdlib → third-party → local
- **Classes**: PascalCase (e.g., `MirrorConfig`)
- **Constants**: UPPER_CASE (e.g., `CONFIG_FILE`)
- **Error handling**: Try/except with specific exceptions, log to stderr
- **Paths**: Use `os.path.join()` for compatibility

Example:
```python
#!/usr/bin/env python3
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
from croniter import croniter

CONFIG_FILE = "/opt/cgit/data/config.json"
```

### Dockerfile & Docker Compose
- **Multi-stage**: Separate builder/runtime stages
- **Layering**: Combine RUN commands with `&&`
- **ARG vs ENV**: ARG for build-time, ENV for runtime
- **Order**: packages → cleanup → users → config → permissions

### s6-rc Services
- **Longrun**: `#!/command/execlineb -P`
- **Dependencies**: Use `dependencies.d/` directories
- **Permissions**: Scripts 755, configs 644

### Naming Conventions
- **Files**: kebab-case (scripts), camelCase (configs)
- **Directories**: kebab-case
- **Functions**: snake_case with descriptive names

### Error Handling & Security
- **Shell**: `set -e`, validate inputs, meaningful errors
- **Python**: Try/except blocks, log to stderr
- **File ops**: Check before destructive operations with `${VAR:?}`
- **Permissions**: Scripts 755, configs 644, secrets 600
- **Input validation**: Always validate external inputs
- **Graceful shutdown**: Handle SIGTERM/SIGINT in daemons

## Repository Structure

```
docker-cgit/
├── Dockerfile              # Multi-stage build (builder → runtime)
├── docker-compose.yml      # Service orchestration
├── config/                 # Default configurations (cgitrc, nginx, sshd)
├── scripts/
│   ├── repo               # Main CLI entry point (104 lines)
│   ├── mirror-*.py        # Mirror sync components
│   └── lib/
│       ├── repo-utils.sh  # Utilities (validation, cache)
│       ├── repo-core.sh   # Core ops (create, clone, delete, list)
│       └── repo-mirror.sh # Mirror ops (enable, sync, status)
└── s6-rc/                 # Service definitions (nginx, sshd, fcgiwrap, etc.)
```

## Key Patterns

### Idempotent Operations
```bash
# Check before creating
[ ! -d "$REPO_DIR/$name.git" ] && git init --bare "$REPO_DIR/$name.git"

# Python: os.makedirs(path, exist_ok=True)
```

### Configuration
- **Bash defaults**: `${VAR:-default}`
- **JSON configs**: Store in `/opt/cgit/data/` for persistence
- **Git metadata**: `git config --local cgit.name "value"`

### Background Services
- Low priority: `nice -n 19` to avoid impacting web performance
- Graceful shutdown: Handle SIGTERM/SIGINT
- Parallel ops: `ThreadPoolExecutor` with concurrency limits
- Logging: Both file and stdout for container compatibility

## CI/CD

- **Multi-arch**: amd64, arm64 via GitHub Actions
- **Registry**: ghcr.io (GitHub Container Registry)
- **Tagging**: Semantic versioning (v*.*.*, latest on main)

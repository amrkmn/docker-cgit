# AGENTS.md

This file provides guidance for agentic coding agents working with the docker-cgit repository.

## Build & Development Commands

### Docker Commands
```bash
# Build and start
docker compose build                          # Build image locally
docker compose up -d                          # Start container in detached mode
docker compose logs -f                        # View live logs

# Development & debugging
docker compose exec cgit sh                   # Shell into running container
docker build --target=builder -t cgit-builder .  # Build specific stage for debugging
docker compose down                           # Stop and remove containers

# Health checks
docker compose ps                             # Check container status
docker compose exec cgit wget --spider http://localhost:80/
```

### Repository Management
All repository operations use the unified `repo` command (scripts/repo:1).

```bash
# Core operations
docker compose exec cgit repo create test-repo "Description" "Owner <email>"
docker compose exec cgit repo clone https://github.com/user/repo.git
docker compose exec cgit repo list           # List all repositories with metadata
docker compose exec cgit repo update test-repo  # Update mirrored repository

# Destructive operations
docker compose exec cgit repo delete test-repo --yes  # Skip confirmation
docker compose exec cgit repo clear-cache     # Clear cgit cache after changes
```

### Testing
No automated test suite exists. Manual testing workflow:

```bash
# Test Git protocols
ssh -p 2222 git@localhost                     # Verify SSH access
git clone ssh://git@localhost:2222/test-repo.git  # Test SSH clone (read-write)
git clone http://localhost:8081/test-repo.git     # Test HTTP clone (read-only)
git clone git://localhost:9418/test-repo.git      # Test git:// protocol (read-only)

# Test services
docker compose exec cgit s6-rc -a list        # Verify all services running
docker compose exec cgit nginx -t             # Validate nginx config
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

### Python Scripts (Syntax Highlighting Filters)
- Python 3 syntax, PEP 8 style guide
- Import order: stdlib → third-party → local
- Error handling with try/except blocks (config/filters/about-formatting.sh:15)
- Use markdown library for rendering (with fenced_code, tables, codehilite extensions)

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
- **File operations**: Conditional checks before destructive operations
- **Permissions**: Scripts 755, configs 644, secrets 600, sensitive dirs 700
- **Security**: Never log secrets, use read-only mounts, minimal user permissions
- **Input validation**: Validate external inputs (scripts/repo:22 validates repo names)

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
├── scripts/repo           # Unified repository management CLI (in container PATH)
└── s6-rc/                 # s6-overlay service definitions
    ├── prepare-services   # Oneshot: SSH key setup
    ├── nginx              # Longrun: Web server
    ├── fcgiwrap           # Longrun: FastCGI wrapper for cgit.cgi
    ├── sshd               # Longrun: SSH server
    └── git-daemon         # Longrun: git:// protocol server
```

## CI/CD Pipeline

- **Multi-arch builds**: amd64, arm64 via GitHub Actions (matrix strategy)
- **Build system**: Docker Buildx with QEMU for cross-platform
- **Registry**: GitHub Container Registry (ghcr.io)
- **Caching**: GitHub Actions cache + registry cache
- **Tagging**: Semantic versioning (v*.*.*, latest on main branch)
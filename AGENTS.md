# AGENTS.md

This file provides guidance for agentic coding agents working with this docker-cgit repository.

## Build & Development Commands

### Docker Commands
```bash
# Build image locally
docker compose build

# Build specific stage (for debugging)
docker build --target=builder -t cgit-builder .

# Start container
docker compose up -d

# View logs
docker compose logs -f

# Stop container
docker compose down

# Shell into running container
docker compose exec cgit sh

# Test container health
docker compose ps
docker compose exec cgit wget --spider http://localhost:80/
```

### Repository Management (via unified `repo` command)
```bash
# Create test repository
docker compose exec cgit repo create test-repo "Test Repository"

# Clone/mirror repository
docker compose exec cgit repo clone https://github.com/user/repo.git

# List repositories
docker compose exec cgit repo list

# Update mirrored repository
docker compose exec cgit repo update test-repo

# Delete repository (interactive)
docker compose exec -it cgit repo delete test-repo

# Delete repository (non-interactive)
docker compose exec cgit repo delete test-repo --yes

# Clear cgit cache
docker compose exec cgit repo clear-cache

# Show help
docker compose exec cgit repo help
```

### Testing Git Operations
```bash
# Test SSH connection
ssh -p 2222 -v git@localhost

# Clone via SSH (read-write)
git clone ssh://git@localhost:2222/test-repo.git

# Clone via HTTP (read-only)
git clone http://localhost:8081/test-repo.git

# Clone via git protocol (read-only)
git clone git://localhost:9418/test-repo.git

# Push via SSH
cd test-repo
git push origin main
```

### Service Validation
```bash
# Validate s6-rc services
docker compose exec cgit s6-rc -a list

# Check nginx config
docker compose exec cgit nginx -t

# Test cgit.cgi manually
docker compose exec cgit /opt/cgit/app/cgit.cgi
```

## Code Style Guidelines

### Shell Scripts
- Use `#!/bin/bash` with `set -e` for error handling
- Quote all variables: `"$VAR"` not `$VAR`
- Use UPPER_CASE for environment and global variables
- Use lower_case with underscores for local variables
- Functions use `function_name()` format without `function` keyword
- Indent with 4 spaces (no tabs)
- Add comments for complex logic
- Use `local` for function-local variables
- Validate input parameters and provide usage help
- Consolidate functionality into unified commands (e.g., `repo` script)

Example:
```bash
#!/bin/bash
set -e

REPO_NAME="$1"
REPO_DIR="${REPO_DIR:-/opt/cgit/data/repositories}"

validate_repo_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid repository name"
        exit 1
    fi
}
```

### Dockerfile
- Multi-stage builds with descriptive comments
- Group related RUN commands with `&&`
- Use ARG for versions, ENV for runtime
- Keep layers minimal (combine commands)
- Use specific image tags (avoid `latest`)
- Order instructions: system packages → cleanup → user creation → config

### Docker Compose
- Use YAML anchors for repeated configurations
- Environment variables for customization
- Descriptive service names
- Proper volume mappings
- Restart policies defined

### Configuration Files
- cgitrc: Follow upstream documentation format
- Use absolute paths in container contexts
- Include comments for non-obvious settings
- Separate user-configurable from system settings

### s6-rc Services
- Longrun services use `#!/command/execlineb -P`
- Oneshot services use `#!/command/execlineb -P` for up scripts
- Define dependencies via `dependencies.d/` directories
- Service type in `type` file (oneshot, longrun, bundle)
- Proper permissions on executable files
- Consolidate related preparation into single oneshot service where possible

### Python Scripts
- Use Python 3 syntax
- Follow PEP 8 style guide
- Docstrings for functions and classes
- Type hints where appropriate
- Error handling with try/except blocks

### File Permissions
- Executable scripts: 755
- Configuration files: 644
- Sensitive files (SSH keys): 600
- Directories: 755 (or 700 for sensitive dirs)

### Naming Conventions
- Files: kebab-case for scripts, camelCase for configs
- Directories: kebab-case
- Variables: UPPER_CASE for env vars, lower_case for locals
- Functions: snake_case with descriptive names
- Services: kebab-case in docker-compose

### Error Handling
- Use `set -e` in shell scripts
- Validate inputs before processing
- Provide meaningful error messages
- Exit with non-zero status on errors
- Use conditional checks for file operations

### Security Best Practices
- Never log secrets or passwords
- Use read-only mounts where possible
- Minimal user permissions
- Validate all external inputs
- Use HTTPS for remote operations

### Git Configuration
- Repository metadata via `git config --local cgit.*`
- Standard fields: name, desc, owner, section, defbranch, readme
- Use colon prefix for README files in cgit.readme

### Testing Strategy
- Manual testing via docker compose
- Service health checks
- Git operation validation
- Configuration file validation
- Container startup verification

## Repository Structure

```
docker-cgit/
├── Dockerfile              # Multi-stage build
├── docker-compose.yml      # Container orchestration
├── config/                 # Configuration files
│   ├── cgitrc             # Default cgit config
│   ├── filters/           # Syntax highlighting filters
│   ├── nginx/             # Web server config
│   └── sshd_config        # SSH server config
├── scripts/               # Helper scripts (added to PATH)
│   └── repo               # Unified repository management (contains all functions)
├── s6-rc/                 # Service definitions
└── entrypoint.sh          # Auto-configuration wrapper
```

## CI/CD Pipeline

- Multi-arch builds (amd64/arm64) via GitHub Actions
- QEMU for cross-platform builds
- GitHub Container Registry for distribution
- Automated testing on PRs
- Semantic versioning for tags
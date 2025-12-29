# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Docker image for [cgit](https://git.zx2c4.com/cgit/) (fast web frontend for git repositories) with SSH support. Built on Alpine Linux with s6-overlay for process supervision. Published as multi-arch (amd64/arm64) to GitHub Container Registry.

## Build & Development Commands

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

# Create test repository using unified repo command
docker compose exec cgit repo create test-repo "Test Repository"

# Validate s6-rc services (after starting)
docker compose exec cgit s6-rc -a list

# Check container health
docker compose ps
docker compose exec cgit wget --spider http://localhost:80/
```

## Repository Management

All repository operations use the unified `repo` command (wrapper script in `/opt/cgit/bin/repo`):

```bash
# Create a new repository
docker compose exec cgit repo create my-project "My Description" "Owner <email>"

# Clone/mirror a repository (supports GitHub, GitLab, Codeberg, etc.)
docker compose exec cgit repo clone https://github.com/user/repo.git

# Update a mirrored repository (fetch latest changes)
docker compose exec cgit repo update my-project

# List all repositories
docker compose exec cgit repo list

# Delete a repository (non-interactive, requires --yes flag)
docker compose exec cgit repo delete my-project --yes

# Delete a repository (interactive)
docker compose exec -it cgit repo delete my-project

# Clear cgit cache manually
docker compose exec cgit repo clear-cache

# Show help
docker compose exec cgit repo help
```

**Note**: Repository operations (create, delete, clone) automatically clear the cgit cache.

## Testing Git Operations

```bash
# Test SSH connection (port based on docker-compose.yml)
ssh -p 2222 -v git@localhost

# Clone via SSH (read-write) - simplified path due to git-shell-wrapper.sh
git clone ssh://git@localhost:2222/test-repo.git

# Clone via HTTP (read-only)
git clone http://localhost:8081/test-repo.git

# Clone via git protocol (read-only, port 9418)
git clone git://localhost:9418/test-repo.git

# Push via SSH
cd test-repo
git push origin main
```

## Architecture

### Multi-stage Docker Build
- **Stage 1 (builder)**: Compiles cgit from source with `cgit_build.conf` settings
  - Clones cgit and git submodules from upstream (configurable via CGIT_GIT_URL and CGIT_VERSION args)
  - Applies build configuration (NO_REGEX, NO_GETTEXT for musl compatibility)
  - Installs to `/opt/cgit/app/`
- **Stage 2 (runtime)**: Alpine-based image with nginx, fcgiwrap, openssh-server, git-daemon, and s6-overlay
  - Copies compiled cgit from builder
  - Sets up git user (UID/GID 1000, configurable via PUID/PGID)
  - Installs Python 3 with Pygments for syntax highlighting, plus Chroma for enhanced language support
  - Installs rst2html (docutils) for reStructuredText README rendering
  - Configures all services via s6-rc

### Services (s6-overlay/s6-rc managed)

Four long-running services in `s6-rc/user/contents.d/`:
- **sshd**: SSH server for git push/pull (port 22 internal, mapped to 2222 by default)
- **fcgiwrap**: FastCGI wrapper executing cgit.cgi and git-http-backend
- **nginx**: Web server for cgit UI and HTTP git operations (port 80 internal, mapped to 8081)
- **git-daemon**: Git protocol server for read-only git:// clones (port 9418)

Service startup coordination:
1. **cgit-base** (oneshot) - Base bundle, runs first
2. **prepare-user** (oneshot, depends on cgit-base) - Adjusts git user UID/GID based on PUID/PGID env vars
3. **prepare-sshd** (oneshot, depends on cgit-base) - Generates SSH host keys if missing
4. **prepare-fcgiwrap** (oneshot, depends on cgit-base) - Prepares fcgiwrap socket directory
5. **sshd** (longrun, depends on prepare-sshd) - SSH daemon
6. **fcgiwrap** (longrun, depends on prepare-user, prepare-fcgiwrap) - FastCGI wrapper
7. **git-daemon** (longrun, depends on cgit-base, prepare-user) - Git protocol daemon
8. **nginx** (longrun, depends on fcgiwrap) - Web server
9. **user** (bundle) - Contains all four longrun services

### Key Paths (inside container)
- `/opt/cgit/app/` - cgit.cgi binary and static assets (CSS, etc.)
- `/opt/cgit/cgitrc` - Default cgit configuration (source: `config/cgitrc`)
- `/opt/cgit/data/cgitrc` - User configuration (auto-created by entrypoint.sh, includes default cgitrc)
- `/opt/cgit/data/repositories/` - Git repositories (volume mount: `./data/repositories/`)
- `/opt/cgit/data/cache/` - cgit cache directory (volume mount: `./data/cache/`)
- `/opt/cgit/data/ssh/authorized_keys` - SSH public keys (volume mount: `./data/ssh/authorized_keys`)
- `/opt/cgit/filters/` - Syntax highlighting and formatting filters (chroma-highlight.sh, about-formatting.sh, etc.)
- `/opt/cgit/bin/` - Helper scripts (repo, create-repo.sh, clone-repo.sh, etc.) - added to PATH

### SSH Path Rewriting
The `git-shell-wrapper.sh` script allows users to use simplified SSH paths:
- User runs: `git clone ssh://git@host:2222/repo.git`
- Wrapper rewrites to: `/opt/cgit/data/repositories/repo.git`
- Without wrapper, users would need full path: `ssh://git@host:2222/opt/cgit/data/repositories/repo.git`

### HTTP vs SSH vs Git Protocol
- **HTTP**: Read-only clone via nginx (nginx.conf blocks receive-pack, allows upload-pack via git-http-backend)
- **SSH**: Full read-write access via git user with git-shell-wrapper.sh for path rewriting
- **Git protocol (git://)**: Read-only clone via git-daemon (port 9418)

## Code Conventions

- **Dockerfile**: Multi-stage builds; use ARGs for versions; group RUN commands with `&&`
- **Shell scripts**: Use `#!/bin/bash` with `set -e`; quote variables; UPPER_CASE for variable names
- **s6-rc services**: 
  - Longrun services use `#!/command/execlineb -P` for run scripts
  - Oneshot services use `#!/command/execlineb -P` for up scripts
  - Define dependencies via `dependencies.d/` directories
  - Service type defined in `type` file (oneshot, longrun, bundle)
- **File permissions**: Executables 755, sensitive files 600, configs 644

## Configuration Files

- `config/cgitrc` - Default cgit configuration (scan-path, filters, cache, features). Auto-included by `/opt/cgit/data/cgitrc`
- `config/cgit-dark.css` - Dark theme CSS (Catppuccin Mocha color scheme)
- `config/filters/` - Syntax highlighting and formatting filters (chroma-highlight.sh, about-formatting.sh, commit-links.sh, email-gravatar.py)
- `config/sshd_config` - SSH server settings (key-only auth, git user with git-shell-wrapper.sh)
- `config/nginx/default.conf` - Nginx configuration for cgit, git-http-backend, and HTTP git operations
- `cgit_build.conf` - Build-time cgit paths and options (PREFIX, CGIT_SCRIPT_PATH, CACHE_ROOT, etc.)
- `entrypoint.sh` - Auto-configuration wrapper that creates user cgitrc on first run

## CI/CD Pipeline

`.github/workflows/build.yml` implements multi-arch builds:
1. **Build job** (matrix: linux/amd64, linux/arm64):
   - Uses QEMU for cross-platform builds
   - Builds per platform and pushes by digest
   - Uses GitHub Actions cache for layers
   - Uploads digest artifacts
2. **Merge job**:
   - Downloads all platform digests
   - Creates multi-arch manifest
   - Tags: latest, branch name, semver, SHA

Triggered on: push to main/develop, tags (v*.*.*), pull requests, manual dispatch

## Volume Mounts (docker-compose.yml)

- `./data:/opt/cgit/data` - All cgit data (repositories, cache, SSH keys, user cgitrc)
  - `./data/repositories/` → `/opt/cgit/data/repositories/` - Git repositories
  - `./data/cache/` → `/opt/cgit/data/cache/` - cgit cache
  - `./data/ssh/authorized_keys` → `/opt/cgit/data/ssh/authorized_keys` - SSH public keys
  - `./data/cgitrc` → `/opt/cgit/data/cgitrc` - User configuration (auto-created on first run)
- Environment: PUID=1000, PGID=1000 (permission management), CGIT_HOST, CGIT_PORT, CGIT_USER_NAME, CGIT_USER_EMAIL
- Ports: 8081:80 (web), 2222:22 (SSH), 9418:9418 (git protocol)
- Restart policy: unless-stopped

## Repository Configuration

Each repository can override cgit settings via `git config --local cgit.*`:
- `cgit.name` - Display name (e.g., "my-project")
- `cgit.desc` - Description
- `cgit.owner` - Owner name/email (e.g., "John Doe <john@example.com>")
- `cgit.section` - Category/group for organizing repositories
- `cgit.defbranch` - Default branch (e.g., "main" or "master")
- `cgit.readme` - README file to render (note: use `:README.md` with colon prefix for cgit to detect it in "about" tab)
- `cgit.clone-url` - Custom clone URLs (space-separated: "git://host/repo.git https://host/repo.git ssh://git@host:2222/repo.git")

Example:
```bash
cd /opt/cgit/data/repositories/my-repo.git
GIT_DIR=. git config --local cgit.name "my-project"
GIT_DIR=. git config --local cgit.readme ":README.md"
```

## Debugging Tips

```bash
# Check service status
docker compose exec cgit s6-rc -a list

# View s6-overlay logs (if S6_LOGGING=1)
docker compose exec cgit ls /run/s6-rc/servicedirs/

# Test nginx config
docker compose exec cgit nginx -t

# Check git user permissions
docker compose exec cgit id git
docker compose exec cgit ls -la /opt/cgit/data/repositories/

# Manually test cgit.cgi
docker compose exec cgit /opt/cgit/app/cgit.cgi

# Check SSH host keys
docker compose exec cgit ls -la /etc/ssh/ssh_host_*

# Test fcgiwrap socket
docker compose exec cgit ls -la /run/fcgiwrap/

# Check git-daemon process
docker compose exec cgit ps aux | grep git-daemon

# View cgit configuration (includes user overrides)
docker compose exec cgit cat /opt/cgit/data/cgitrc

# Check repository git config
docker compose exec cgit sh -c 'cd /opt/cgit/data/repositories/test-repo.git && GIT_DIR=. git config --list | grep cgit'
```

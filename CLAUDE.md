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

# Create test repository
./scripts/init-bare-repo.sh test-repo "Test Repository"

# Validate s6-rc services (after starting)
docker compose exec cgit s6-rc -a list

# Check container health
docker compose ps
docker compose exec cgit wget --spider http://localhost:80/
```

## Testing Git Operations

```bash
# Test SSH connection
ssh -p 2223 -v git@localhost

# Clone via SSH (read-write)
git clone ssh://git@localhost:2223/opt/cgit/repositories/test-repo.git

# Clone via HTTP (read-only)
git clone http://localhost:8081/test-repo.git

# Push via SSH
cd test-repo
git push origin main
```

## Architecture

### Multi-stage Docker Build
- **Stage 1 (builder)**: Compiles cgit from source with `cgit_build.conf` settings
  - Clones cgit and git submodules from upstream
  - Applies build configuration (NO_REGEX, NO_GETTEXT for musl compatibility)
  - Installs to `/opt/cgit/app/`
- **Stage 2 (runtime)**: Alpine-based image with nginx, fcgiwrap, openssh-server, and s6-overlay
  - Copies compiled cgit from builder
  - Sets up git user (UID/GID 1000, configurable via PUID/PGID)
  - Installs Python 3 with Pygments for syntax highlighting
  - Configures all services via s6-rc

### Services (s6-overlay/s6-rc managed)

Three long-running services in `s6-rc/user/contents.d/`:
- **sshd**: SSH server for git push/pull (port 22 internal, mapped to 2223)
- **fcgiwrap**: FastCGI wrapper executing cgit.cgi
- **nginx**: Web server for cgit UI and HTTP git operations (port 80 internal, mapped to 8081)

Service startup coordination:
1. **cgit-base** (oneshot) - Base bundle, runs first
2. **prepare-user** (oneshot, depends on cgit-base) - Adjusts git user UID/GID based on PUID/PGID env vars
3. **prepare-sshd** (oneshot, depends on cgit-base) - Generates SSH host keys if missing
4. **prepare-fcgiwrap** (oneshot, depends on cgit-base) - Prepares fcgiwrap socket directory
5. **sshd** (longrun, depends on prepare-sshd) - SSH daemon
6. **fcgiwrap** (longrun, depends on prepare-user, prepare-fcgiwrap) - FastCGI wrapper
7. **nginx** (longrun, depends on fcgiwrap) - Web server
8. **user** (bundle) - Contains all three longrun services

### Key Paths (inside container)
- `/opt/cgit/app/` - cgit.cgi binary and static assets
- `/opt/cgit/cgitrc` - cgit configuration (source: `config/cgitrc`)
- `/opt/cgit/repositories/` - git repositories (volume mount via docker-compose: `./data:/opt/cgit`)
- `/opt/cgit/cache/` - cgit cache directory
- `/opt/cgit/filters/` - syntax highlighting and formatting filters (compiled in Dockerfile)
- `/opt/cgit/ssh/` - SSH authorized_keys location (internal)
- `/home/git/.ssh/authorized_keys` - Actual SSH keys file (volume mount via docker-compose)

### SSH Path Rewriting
The `git-shell-wrapper.sh` script allows users to use simplified SSH paths:
- User runs: `git clone ssh://git@host:2223/repo.git`
- Wrapper rewrites to: `/opt/cgit/repositories/repo.git`
- Without wrapper, users would need full path: `ssh://git@host:2223/opt/cgit/repositories/repo.git`

### HTTP vs SSH
- **HTTP**: Read-only clone via nginx (nginx.conf blocks receive-pack, allows upload-pack)
- **SSH**: Full read-write access via git-shell restricted user

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

- `config/cgitrc` - Main cgit runtime configuration (scan-path, filters, cache, features, clone URLs)
- `config/sshd_config` - SSH server settings (key-only auth, git user restricted to git-shell)
- `config/nginx/default.conf` - Nginx configuration for cgit and HTTP git operations
- `cgit_build.conf` - Build-time cgit paths and options (PREFIX, CGIT_SCRIPT_PATH, etc.)

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

- `./data:/opt/cgit` - All cgit data (repositories, cache, SSH keys)
- Environment: PUID=1000, PGID=1000 for permission management
- Ports: 8081:80 (web), 2223:22 (SSH)
- Health check: wget spider on http://localhost:80/
- Resource limits: 512M limit, 256M reservation

## Repository Configuration

Each repository can override cgit settings via `git config --local cgit.*`:
- `cgit.name` - Display name
- `cgit.desc` - Description
- `cgit.owner` - Owner name/email
- `cgit.section` - Category/group
- `cgit.defbranch` - Default branch (e.g., "main")
- `cgit.readme` - README file to render

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
docker compose exec cgit ls -la /opt/cgit/repositories/

# Manually test cgit.cgi
docker compose exec cgit /opt/cgit/app/cgit.cgi

# Check SSH host keys
docker compose exec cgit ls -la /etc/ssh/ssh_host_*

# Test fcgiwrap socket
docker compose exec cgit ls -la /run/fcgiwrap/
```

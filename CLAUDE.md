# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Docker image for [cgit](https://git.zx2c4.com/cgit/) (fast web frontend for git repositories) with SSH support. Built on Alpine Linux with s6-overlay for process supervision.

## Build & Development Commands

```bash
# Build image
docker compose build

# Build specific stage (for debugging)
docker build --target=builder -t cgit-builder .

# Start container
docker compose up -d

# View logs
docker compose logs -f

# Stop container
docker compose down

# Create test repository
./scripts/init-bare-repo.sh test-repo "Test Repository"

# Validate s6-rc services (after starting)
docker compose exec cgit s6-rc -a list

# Check container health
docker compose ps
docker compose exec cgit wget --spider http://localhost:80/
```

## Architecture

### Multi-stage Docker Build
- **Stage 1 (builder)**: Compiles cgit from source with `cgit_build.conf` settings
- **Stage 2 (runtime)**: Alpine-based image with nginx, fcgiwrap, openssh-server, and s6-overlay

### Services (s6-overlay managed)
Three long-running services in `s6-rc/`:
- **sshd**: SSH server for git push/pull (port 22 internal, mapped to 2223)
- **fcgiwrap**: FastCGI wrapper executing cgit.cgi
- **nginx**: Web server for cgit UI and HTTP git operations (port 80 internal, mapped to 8081)

Service startup is coordinated via `dependencies.d/` directories. Oneshot services (`prepare-sshd`, `prepare-fcgiwrap`, `prepare-user`) run before their dependent longrun services.

### Key Paths (inside container)
- `/opt/cgit/app/` - cgit.cgi binary
- `/opt/cgit/cgitrc` - cgit configuration (source: `config/cgitrc`)
- `/opt/cgit/repositories/` - git repositories (volume mount)
- `/opt/cgit/cache/` - cgit cache
- `/opt/cgit/filters/` - syntax highlighting and formatting filters
- `/opt/cgit/ssh/` - SSH authorized_keys (volume mount)

## Code Conventions

- **Dockerfile**: Multi-stage builds; use ARGs for versions; group RUN commands with `&&`
- **Shell scripts**: Use `#!/bin/bash` with `set -e`; quote variables; UPPER_CASE for variable names
- **s6-rc services**: Use `#!/command/execlineb -P` for run scripts; define dependencies via `dependencies.d/`
- **File permissions**: Executables 755, sensitive files 600, configs 644

## Configuration Files

- `config/cgitrc` - Main cgit runtime configuration (scan-path, filters, cache, features)
- `config/sshd_config` - SSH server settings (key-only auth, git user restricted to git-shell)
- `config/nginx/default.conf` - Nginx configuration for cgit and HTTP git operations
- `cgit_build.conf` - Build-time cgit paths and options

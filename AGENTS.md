# Agent Guidelines for docker-cgit

## Build & Test Commands
- **Build image**: `docker compose build`
- **Start container**: `docker compose up -d`
- **View logs**: `docker compose logs -f`
- **Stop container**: `docker compose down`
- **Test build stage**: `docker build --target=builder -t cgit-builder .`
- **Create test repo**: `./scripts/init-bare-repo.sh test-repo "Test Repository"`
- **Validate s6-rc**: `docker compose exec cgit s6-rc -a list` (after starting)
- **Check health**: `docker compose ps` or `docker compose exec cgit wget --spider http://localhost:80/`

## Code Style & Conventions
- **Dockerfile**: Multi-stage builds; Alpine Linux base; use ARGs for versions; group RUN commands with `&&`
- **Shell scripts**: Use `#!/bin/bash`; `set -e` for error handling; quote all variables; descriptive variable names in UPPER_CASE
- **s6-rc services**: Use `#!/command/execlineb -P` for run/up scripts; services in longrun/oneshot/bundle types; dependencies via `dependencies.d/` or `contents.d/`
- **Configuration**: Clear comments; security-first (key-only auth, restricted shells); explicit ownership/permissions for files
- **File permissions**: Executable scripts (755), sensitive files (600), directories (755), configs readable (644)
- **Naming**: Lowercase with hyphens for files/dirs; descriptive service names; `.example` suffix for templates
- **Documentation**: Inline comments for complex logic; examples in usage strings; security notes where relevant
- **Docker Compose**: Use named volumes; mount sensitive files read-only (`:ro`); expose only necessary ports
- **Error handling**: Shell scripts exit on error (`set -e`); validate inputs; provide usage examples

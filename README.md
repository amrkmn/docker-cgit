# cgit Docker Image

A lightweight Docker image for [cgit](https://git.zx2c4.com/cgit/), a fast web frontend for git repositories, with SSH support. Built on Alpine Linux with s6-overlay for process supervision.

## Features

- Web interface for browsing repositories
- SSH support for git push/pull (port 2222)
- HTTP clone support (read-only)
- Mirror repositories from GitHub, GitLab, Codeberg, or any git service
- Syntax highlighting and README rendering
- Multi-arch support (amd64/arm64)

## Quick Start

Create `docker-compose.yml`:

```yaml
services:
  cgit:
    image: ghcr.io/amrkmn/cgit:latest
    container_name: cgit
    hostname: cgit
    ports:
      - "8081:80"
      - "2222:22"
    volumes:
      - ./data/repositories:/opt/cgit/repositories
      - ./data/ssh:/opt/cgit/ssh
      - ./data/cache:/opt/cgit/cache
    environment:
      - PUID=1000
      - PGID=1000
      - CGIT_HOST=localhost
      - CGIT_OWNER=Your Name <email@example.com>
    restart: unless-stopped
```

```bash
# Start container
docker compose up -d

# Access cgit web interface
open http://localhost:8081
```

## Changing Ports

You can change the SSH port mapping in `docker-compose.yml`:

```yaml
services:
  cgit:
    ports:
      - "8081:80"      # Web interface (host:container)
      - "22:22"        # SSH on standard port (requires root/sudo)
      # - "2223:22"    # Or use any other port
```

**Note**: Mapping to port 22 requires root/sudo privileges.

## Managing Repositories

All repository operations can be done using the unified `repo` command:

```bash
# Create a new repository
docker compose exec cgit repo create my-project "My Description" "Owner <email>"

# Clone/mirror a repository
docker compose exec cgit repo clone https://github.com/user/repo.git

# List all repositories
docker compose exec cgit repo list

# Delete a repository
docker compose exec cgit repo delete my-project

# Clear cgit cache manually
docker compose exec cgit repo clear-cache

# Show help
docker compose exec cgit repo help
```

> **Note**: The old individual scripts (`create-repo.sh`, `clone-repo.sh`, etc.) are still available for backward compatibility.
> **Note**: Repository changes (create, delete, clone) automatically clear the cgit cache, so new repositories appear immediately without restarting the container.

## Creating Repositories

Use the `repo` command to manage repositories (see "Managing Repositories" section above).

Update a mirrored repository:
```bash
docker compose exec cgit sh -c "cd /opt/cgit/repositories/my-repo.git && git remote update"
```

## Git Operations

### Clone via SSH (read-write)
```bash
# Default setup
git clone ssh://git@localhost:2222/my-project.git

# If using port 22
git clone git@localhost:my-project.git

# If using port 2223
git clone ssh://git@localhost:2223/my-project.git
```

### Clone via HTTP (read-only)
```bash
git clone http://localhost:8081/my-project.git
```

## Configuration

Edit these files to customize:
- `config/cgitrc` - Main cgit configuration
- `config/sshd_config` - SSH server settings
- `config/nginx/default.conf` - Web server configuration

## SSH Authentication

Add your SSH public key to the container:

```bash
# Copy your public key
cat ~/.ssh/id_ed25519.pub >> data/ssh/authorized_keys

# Restart container
docker compose restart
```

## Environment Variables

- `PUID` - User ID for git user (default: 1000)
- `PGID` - Group ID for git user (default: 1000)
- `CGIT_HOST` - Hostname for clone URLs (default: localhost)
- `CGIT_PORT` - Port for clone URLs (default: 2222)
- `CGIT_OWNER` - Default owner name for new repositories (default: Unknown)

Example:
```yaml
environment:
  - CGIT_HOST=git.example.com
  - CGIT_PORT=22
  - CGIT_OWNER="John Doe <john@example.com>"
```

## Ports

- **8081** - Web interface (cgit)
- **2222** - SSH server (git operations)

## Volumes

- `./data/repositories` - Git repositories
- `./data/ssh` - SSH authorized_keys
- `./data/cache` - cgit cache

## License

GPL-2.0 (same as cgit)

## Links

- [cgit upstream](https://git.zx2c4.com/cgit/)
- [Docker image](https://github.com/amrkmn/docker-cgit)

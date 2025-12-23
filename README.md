# cgit Docker Image

A lightweight Docker image for [cgit](https://git.zx2c4.com/cgit/), a fast web frontend for git repositories, with SSH support. Built on Alpine Linux with s6-overlay for process supervision.

## Features

- Web interface for browsing repositories
- SSH support for git push/pull (port 2223)
- HTTP clone support (read-only)
- Syntax highlighting and README rendering
- Multi-arch support (amd64/arm64)

## Quick Start

```bash
# Pull the image
docker compose pull

# Start the container
docker compose up -d

# Access cgit web interface
open http://localhost:8081
```

## Creating Repositories

```bash
# Using the helper script
./scripts/init-bare-repo.sh my-project "My Project Description"

# Or manually
mkdir -p data/repositories
cd data/repositories
git init --bare my-project.git
cd my-project.git
git config cgit.name "My Project"
git config cgit.desc "My Project Description"
```

## Git Operations

### Clone via SSH (read-write)
```bash
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

## Ports

- **8081** - Web interface (cgit)
- **2223** - SSH server (git operations)

## Volumes

- `./data` - Contains repositories, cache, and SSH keys

## License

GPL-2.0 (same as cgit)

## Links

- [cgit upstream](https://git.zx2c4.com/cgit/)
- [Docker image](https://github.com/amrkmn/docker-cgit)

# cgit Docker Image

A lightweight Docker image for [cgit](https://git.zx2c4.com/cgit/), a fast web frontend for git repositories, with SSH support for push/pull operations. Built on Alpine Linux with s6-overlay for reliable process supervision.

## Features

- **Web Interface**: Clean, fast web UI for browsing repositories (port 8080)
- **SSH Git Operations**: Secure push/pull via SSH with key-based authentication (port 2222)
- **HTTP Clone Support**: Read-only git clone over HTTP (push disabled)
- **Syntax Highlighting**: Source code syntax highlighting via highlight
- **Markdown/RST Rendering**: Render README files in various formats
- **Persistent Cache**: Configurable cgit cache for better performance
- **Process Supervision**: s6-overlay manages all services (nginx, fcgiwrap, sshd)
- **Lightweight**: Alpine Linux base (~150-200MB image)

## Quick Start

### 1. Prepare Your Environment

```bash
# Clone or create project directory
mkdir -p ~/cgit-docker && cd ~/cgit-docker

# Create directories for repositories and SSH keys
mkdir -p ~/git

# Add your SSH public key for git authentication
cat ~/.ssh/id_ed25519.pub > cgit_authorized_keys
```

### 2. Build the Image

```bash
docker compose build
```

### 3. Create a Test Repository

```bash
# Initialize a bare repository
./scripts/init-bare-repo.sh my-project

# Or manually:
cd ~/git
git init --bare my-project.git
cd my-project.git
git config --local cgit.name "My Project"
git config --local cgit.desc "My awesome project"
```

### 4. Start the Container

```bash
docker compose up -d
```

### 5. Access cgit

Open your browser to: http://localhost:8080

## Git Operations

### SSH (Recommended for Push/Pull)

```bash
# Clone via SSH
git clone ssh://git@localhost:2222/opt/cgit/repositories/my-project.git

# Add remote to existing repo
git remote add origin ssh://git@localhost:2222/opt/cgit/repositories/my-project.git

# Push changes
git push origin main
```

**Note**: SSH runs on port **2222** (not standard port 22)

### HTTP (Read-Only Clone)

```bash
# Clone via HTTP (read-only)
git clone http://localhost:8080/my-project.git

# Push over HTTP is disabled (returns 403)
```

## Configuration

### Repository Configuration

Each repository can have custom cgit settings via git config:

```bash
cd ~/git/my-project.git
git config --local cgit.name "Display Name"
git config --local cgit.desc "Repository description"
git config --local cgit.owner "Your Name <your@email.com>"
git config --local cgit.section "Category"
git config --local cgit.homepage "https://example.com"
git config --local cgit.defbranch "main"
git config --local cgit.readme "README.md"
```

### Main cgit Configuration

Edit `config/cgitrc` to customize:

- Site title and description
- Repository scanning paths
- Clone URLs (SSH/HTTP)
- Cache settings
- Filters and extensions

### SSH Configuration

Edit `config/sshd_config` to customize SSH server settings. Default settings:

- Port: 2222
- Authentication: Public key only (no passwords)
- Forced command: git-shell (restricted)
- Only `git` user allowed

### Nginx Configuration

Edit `config/nginx/default.conf` to customize web server settings:

- Port: 8080
- HTTP git operations (upload-pack only, receive-pack blocked)
- Static file caching
- FastCGI parameters

## Directory Structure

```
cgit-docker/
├── Dockerfile              # Multi-stage build definition
├── docker-compose.yml      # Compose configuration for personal use
├── cgit_build.conf         # Build-time cgit configuration
├── cgit_authorized_keys    # Your SSH public keys (gitignored)
├── LICENSE                 # GPL-2.0 license
├── README.md              # This file
├── config/
│   ├── cgitrc             # Runtime cgit configuration
│   ├── sshd_config        # SSH server configuration
│   └── nginx/
│       └── default.conf   # Nginx web server configuration
├── s6-rc/                 # s6-overlay service definitions
│   ├── prepare-fcgiwrap/  # Oneshot: prepare fcgiwrap socket dir
│   ├── prepare-sshd/      # Oneshot: prepare SSH host keys
│   ├── fcgiwrap/          # Longrun: FastCGI wrapper for cgit
│   ├── sshd/              # Longrun: SSH server for git operations
│   ├── nginx/             # Longrun: Web server
│   └── user/              # Bundle: all user services
└── scripts/
    └── init-bare-repo.sh  # Helper to create new bare repos
```

## Volume Mounts

The docker-compose.yml mounts:

- `~/git:/opt/cgit/repositories` - Your git repositories
- `./cgit_authorized_keys:/home/git/.ssh/authorized_keys:ro` - SSH public keys (read-only)
- `cgit-cache:/opt/cgit/cache` - Named volume for persistent cache

## Services

The container runs three services via s6-overlay:

1. **sshd** - SSH server for git push/pull (port 2222)
2. **fcgiwrap** - FastCGI wrapper executing cgit.cgi
3. **nginx** - Web server serving cgit UI and handling git HTTP operations (port 8080)

Service dependencies:
- nginx depends on fcgiwrap
- sshd and fcgiwrap depend on their respective prepare-* oneshots

## Troubleshooting

### Check Service Status

```bash
# View container logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# Check specific service
docker-compose exec cgit s6-rc -a list
```

### SSH Connection Issues

```bash
# Test SSH connection
ssh -p 2222 -v git@localhost

# Verify authorized_keys permissions (should be 600)
docker-compose exec cgit ls -la /home/git/.ssh/

# Check SSH daemon logs
docker-compose logs | grep sshd
```

### Repository Not Showing

```bash
# Verify repository ownership (should be git:git)
docker-compose exec cgit ls -la /opt/cgit/repositories/

# Fix permissions if needed
docker-compose exec cgit chown -R git:git /opt/cgit/repositories/

# Check cgit scan-path configuration
docker-compose exec cgit cat /opt/cgit/app/cgitrc | grep scan-path
```

### Cache Issues

```bash
# Clear cgit cache
docker-compose exec cgit rm -rf /opt/cgit/cache/*

# Restart services
docker-compose restart
```

### Git Push Fails

```bash
# Ensure SSH key is added
cat ~/.ssh/id_ed25519.pub >> cgit_authorized_keys

# Check git user shell
docker-compose exec cgit grep git /etc/passwd
# Should show: git:x:1000:1000::/home/git:/usr/bin/git-shell

# Verify repository is bare
ls ~/git/my-project.git/config
```

### HTTP Push Returns 403

This is intentional - HTTP push is disabled for security. Use SSH for push operations:

```bash
git remote set-url origin ssh://git@localhost:2222/opt/cgit/repositories/my-project.git
```

## Advanced Usage

### Multiple SSH Keys

Add multiple keys to `cgit_authorized_keys`:

```bash
cat ~/.ssh/id_ed25519.pub >> cgit_authorized_keys
cat ~/.ssh/id_rsa.pub >> cgit_authorized_keys
```

### Custom Repository Groups

Edit `config/cgitrc` and use `section` to group repositories:

```bash
cd ~/git/my-project.git
git config --local cgit.section "Personal Projects"
```

### Enable/Disable Features

Edit `config/cgitrc` to toggle features:

```
enable-commit-graph=1
enable-log-filecount=1
enable-log-linecount=1
enable-tree-linenumbers=1
enable-blame=1
```

### Change Clone URLs

Edit `config/cgitrc`:

```
clone-prefix=ssh://git@your-domain.com:2222/opt/cgit/repositories http://your-domain.com
```

## Security Notes

- SSH uses **key-based authentication only** (no passwords)
- HTTP **push is disabled** (403 Forbidden)
- SSH user is **restricted to git-shell** (no shell access)
- Repositories should be **owned by git:git** (UID/GID 1000)
- authorized_keys is mounted **read-only**
- No X11 or TCP forwarding enabled in SSH

## Building for Production

For production use, consider:

1. **Use secrets** for sensitive data instead of volume mounts
2. **Set up reverse proxy** (Nginx/Traefik) with HTTPS
3. **Change default ports** or use host networking
4. **Enable logging** (set S6_LOGGING=1 in docker-compose.yml)
5. **Backup repositories** regularly
6. **Monitor disk usage** for cache and repositories

## License

This project is licensed under GPL-2.0 (same as cgit).

## Credits

- [cgit](https://git.zx2c4.com/cgit/) - Fast web frontend for git
- [s6-overlay](https://github.com/just-containers/s6-overlay) - Process supervision
- [Alpine Linux](https://alpinelinux.org/) - Lightweight base image

## Contributing

This is a personal Docker image. For issues with cgit itself, see the [official cgit repository](https://git.zx2c4.com/cgit/).

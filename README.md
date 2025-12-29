# cgit Docker Image

A lightweight Docker image for [cgit](https://git.zx2c4.com/cgit/), a fast web frontend for git repositories, with SSH support. Built on Alpine Linux with s6-overlay for process supervision.

## Features

- Web interface for browsing repositories
- **Dark theme** (Catppuccin Mocha color scheme)
- Enhanced syntax highlighting with Chroma (200+ languages, Svelte/Astro/SolidJS support)
- **Git protocol** support for read-only access (git://)
- SSH support for git push/pull (port 2222)
- HTTP clone support (read-only)
- Mirror repositories from GitHub, GitLab, Codeberg, or any git service
- **Automatic mirror synchronization** with configurable schedules (cron expressions)
- README rendering with Markdown/ReST support
- Auto-configuration on first run
- Multi-arch support (amd64/arm64)

## Quick Start

### ⚡ Super Quick (2 commands!)

```bash
# 1. Copy docker-compose.yml
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml

# 2. Start container (cgitrc auto-created on first run!)
docker compose up -d
```

That's it! The container automatically creates `data/cgitrc` on first run.

### 📖 Detailed Setup

See [QUICKSTART.md](QUICKSTART.md) for detailed setup instructions.

### Development (if you cloned this repo)

### 2. Edit Configuration (Optional)

Edit `data/cgitrc` to customize cgit:

```bash
vim data/cgitrc
```

Common settings:
- `css=/cgit-dark.css` - Dark theme (default)
- `snapshots=tar.gz tar.bz2 tar.xz zip` - Download formats
- `readme=:README.md` - README files to display
- `scan-path=/opt/cgit/data/repositories/` - Repository scan path

### 3. Start Container

```bash
docker compose up -d
```

### 4. Access Web Interface

```bash
# Browser
open http://localhost:8081

# Or curl
curl http://localhost:8081
```

### Configuration Files

After running `setup.sh`, you can edit:

| File | Description |
|------|-------------|
| `data/cgitrc` | Main cgit configuration (CSS, filters, scan-path) |
| `data/ssh/authorized_keys` | SSH public keys for git push access |
| `config/cgit-dark.css` | Dark theme CSS (edits require rebuild) |
| `config/cgitrc` | Source configuration (for reference or development) |

## Changing Ports

You can change port mappings in `docker-compose.yml`:

```yaml
services:
  cgit:
    ports:
      - "8081:80"      # Web interface (host:container)
      - "22:22"        # SSH on standard port (requires root/sudo)
      # - "2223:22"    # Or use any other port
      - "9418:9418"    # Git protocol (read-only)
```

**Note**: Mapping to port 22 requires root/sudo privileges.

## Managing Repositories

All repository operations can be done using the unified `repo` command:

```bash
# Create a new repository
docker compose exec cgit repo create my-project "My Description" "Owner <email>"

# Clone/mirror a repository
docker compose exec cgit repo clone https://github.com/user/repo.git

# Clone with automatic synchronization (every 6 hours by default)
docker compose exec cgit repo clone https://github.com/user/repo.git --mirror

# Clone with custom sync schedule (cron expression)
docker compose exec cgit repo clone https://github.com/user/repo.git --mirror --schedule "0 */12 * * *"

# List all repositories
docker compose exec cgit repo list

# Delete a repository (non-interactive, requires --yes flag)
docker compose exec cgit repo delete my-project --yes

# Delete a repository (interactive, requires -it flag)
docker compose exec -it cgit repo delete my-project

# Clear cgit cache manually
docker compose exec cgit repo clear-cache

# Show help
docker compose exec cgit repo help
```

> **Note**: The delete command requires `--yes` flag when running in non-interactive mode (without `-it`).
> **Note**: The old individual scripts (`create-repo.sh`, `clone-repo.sh`, etc.) are still available for backward compatibility.
> **Note**: Repository changes (create, delete, clone) automatically clear the cgit cache, so new repositories appear immediately without restarting the container.

## Automatic Mirror Synchronization

The container includes a background service that automatically synchronizes mirrored repositories on configurable schedules using cron expressions.

### Managing Mirrors

```bash
# Enable auto-sync for an existing repository (every 6 hours by default)
docker compose exec cgit repo mirror enable my-project

# Enable with custom schedule and timeout
docker compose exec cgit repo mirror enable my-project --schedule "0 */12 * * *" --timeout 1200

# Disable auto-sync (keeps repository, stops automatic updates)
docker compose exec cgit repo mirror disable my-project

# List all mirrored repositories
docker compose exec cgit repo mirror list

# List only enabled mirrors
docker compose exec cgit repo mirror list --enabled-only

# Show detailed mirror status
docker compose exec cgit repo mirror status my-project

# Manually sync a repository now
docker compose exec cgit repo mirror sync my-project

# Sync all enabled mirrors
docker compose exec cgit repo mirror sync-all

# View sync logs
docker compose exec cgit repo mirror logs

# View logs for specific repository
docker compose exec cgit repo mirror logs my-project
```

### Configuration

Default settings:
- **Sync interval**: Every 6 hours (`0 */6 * * *`)
- **Timeout**: 600 seconds (10 minutes)
- **Max concurrent syncs**: 3 repositories at a time
- **Log rotation**: Max 10MB per log file, keep 3 rotated logs

All settings can be customized per repository when enabling mirrors.

### Cron Schedule Examples

```bash
# Every hour
--schedule "0 * * * *"

# Every 12 hours
--schedule "0 */12 * * *"

# Daily at 2 AM
--schedule "0 2 * * *"

# Every Monday at midnight
--schedule "0 0 * * 1"

# Every 15 minutes
--schedule "*/15 * * * *"
```

### How It Works

1. **Background Service**: A daemon runs continuously checking for repositories due for sync every 60 seconds
2. **Parallel Processing**: Up to 3 repositories sync in parallel to prevent resource exhaustion
3. **Low Priority**: Syncs run with `nice -n 19` to avoid impacting web server performance
4. **Automatic Retry**: Failed syncs are logged and retried on the next scheduled interval
5. **Status Tracking**: Each sync updates status, timestamp, and next sync time in `/opt/cgit/data/mirror-config.json`
6. **Logging**: All sync operations are logged to `/opt/cgit/data/logs/mirror-sync.log` with automatic rotation

## Customizing Clone URLs

To customize clone URLs for a specific repository, edit the repository's git config:

```bash
cd data/repositories/my-repo.git
GIT_DIR=. git config --local cgit.clone-url "git://git.example.com/my-repo.git https://git.example.com/my-repo.git ssh://git@git.example.com:2222/my-repo.git"
```

This will display three clone options on the repository page:
- `git://git.example.com/my-repo.git` (read-only, port 9418)
- `https://git.example.com/my-repo.git` (read-only, port 80)
- `ssh://git@git.example.com:2222/my-repo.git` (read-write, port 2222)

## Git Operations

### Clone via Git Protocol (read-only, port 9418)
```bash
git clone git://localhost:9418/my-project.git

# If port 9418 is forwarded to standard git port
git clone git://git.example.com/my-project.git
```

### Clone via SSH (read-write)
```bash
# Default setup (port 2222)
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
- `config/cgit-dark.css` - Dark theme styles (Catppuccin Mocha)
- `config/syntax-highlighting-dark.py` - Syntax highlighting filter (monokai theme)
- `config/sshd_config` - SSH server settings
- `config/nginx/default.conf` - Web server configuration

### Syntax Highlighting

The image includes Pygments 3.3.2 with support for **597 programming languages** and **26 color schemes**. The default theme is **monokai** (dark).

To change the color scheme, edit `config/syntax-highlighting-dark.py`:
```python
style='monokai'  # Change to: dracula, gruvbox-dark, solarized-dark, etc.
```

Available color schemes: `abap`, `algol`, `algol_nu`, `arduino`, `autumn`, `borland`, `bw`, `catppuccin-mocha`, `colorful`, `default`, `emacs`, `friendly`, `fruity`, `gruvbox-dark`, `igor`, `lovelace`, `manni`, `material`, `monokai`, `murphy`, `native`, `nord`, `onedark`, `paraiso-dark`, `pastie`, `perldoc`, `rainbow_dash`, `rrt`, `sas`, `solarized-dark`, `solarized-light`, `stata-dark`, `stata-light`, `tango`, `trac`, `vim`, `vs`, `xcode`.

### Supported Languages

Popular languages include: Python, JavaScript, TypeScript, Go, Rust, C, C++, Java, Ruby, PHP, Dockerfile, YAML, JSON, SQL, Bash, HTML, CSS, Markdown, and 580+ more.

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
- `CGIT_PORT` - SSH port for clone URLs (default: 2222)
- `CGIT_USER_NAME` - Default owner name for new repositories (default: Unknown User)
- `CGIT_USER_EMAIL` - Default owner email for new repositories (default: unknown@example.com)

Example:
```yaml
environment:
  - CGIT_HOST=git.example.com
  - CGIT_PORT=22
  - CGIT_USER_NAME="John Doe"
  - CGIT_USER_EMAIL="john@example.com"
```

## Ports

- **8081** - Web interface (cgit)
- **2222** - SSH server (git operations)
- **9418** - Git protocol (read-only)

## Volumes

- `./data/repositories` - Git repositories
- `./data/ssh` - SSH authorized_keys
- `./data/cache` - cgit cache

## Repository Configuration

Each repository can override cgit settings via `git config --local cgit.*`:

```bash
cd data/repositories/my-repo.git

GIT_DIR=. git config --local cgit.name "Display Name"
GIT_DIR=. git config --local cgit.desc "Description of the repository"
GIT_DIR=. git config --local cgit.owner "Owner Name <email@example.com>"
GIT_DIR=. git config --local cgit.section "Category/Group"
GIT_DIR=. git config --local cgit.defbranch "main"
GIT_DIR=. git config --local cgit.readme=":README.md"
```

## Architecture

### Multi-stage Docker Build

- **Stage 1 (builder)**: Compiles cgit from source
- **Stage 2 (runtime)**: Alpine-based image with nginx, fcgiwrap, openssh-server, and s6-overlay

### Services (s6-overlay managed)

- **cgit-base**: Base bundle, runs first
- **prepare-user**: Adjusts git user UID/GID based on PUID/PGID
- **prepare-sshd**: Generates SSH host keys if missing
- **prepare-fcgiwrap**: Prepares fcgiwrap socket directory
- **sshd**: SSH daemon (port 22)
- **fcgiwrap**: FastCGI wrapper executing cgit.cgi
- **git-daemon**: Git protocol server (port 9418, read-only)
- **mirror-sync**: Background daemon for automatic repository synchronization
- **nginx**: Web server for cgit UI (port 80)

## License

GPL-2.0 (same as cgit)

## Links

- [cgit upstream](https://git.zx2c4.com/cgit/)
- [Docker image](https://github.com/amrkmn/docker-cgit)
- [Image on GitHub Container Registry](https://github.com/amrkmn/docker-cgit/pkgs/container/cgit)

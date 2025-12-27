# cgit Quick Start

## 1. Copy Files

```bash
# Create directory
mkdir cgit-docker && cd cgit-docker

# Copy docker-compose.yml
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml
```

## 2. Start Container

```bash
docker compose up -d
```

On first run, the container automatically creates:
- `data/cgitrc` - Main configuration
- `data/repositories/` - Git repositories
- `data/ssh/` - SSH keys
- `data/cache/` - cgit cache

Logs: `[cgit-init] ✓ Created /opt/cgit/data/cgitrc`

## 3. Access

```
http://localhost:8081
```

---

## Adding Repositories

```bash
# SSH into container
docker exec -it cgit sh

# Create a new repository
repo create my-repo "My awesome project"

# Or clone from remote
repo clone https://github.com/user/repo.git my-repo

# List all repositories
repo list
```

## Adding SSH Keys

```bash
# Copy your SSH public key
cat ~/.ssh/id_rsa.pub >> data/ssh/authorized_keys

# Restart container (if keys already added to container)
docker compose restart cgit
```

## Common Configuration

Edit `data/cgitrc` to customize:

| Setting | Example | Description |
|---------|----------|-------------|
| `css` | `css=/cgit-dark.css` | Dark theme (default) |
| `snapshots` | `snapshots=tar.gz tar.bz2 zip` | Download formats |
| `readme` | `readme=:README.md` | README files to display |
| `scan-path` | `scan-path=/opt/cgit/data/repositories/` | Repository scan path (default) |

## Directory Structure

```
data/
├── cgitrc           # Main configuration (edit this!)
├── repositories/     # Git repositories
├── ssh/
│   └── authorized_keys  # SSH public keys
└── cache/            # cgit cache
```

All data is in one `./data/` directory - single volume mount!

# cgit Quick Start

## 1. Copy Files

```bash
# Create directory
mkdir cgit-docker && cd cgit-docker

# Copy docker-compose.yml from https://github.com/amrkmn/docker-cgit
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml
```

## 2. Get Configuration File

```bash
# Extract cgitrc from the image (creates data/cgitrc)
docker run --rm -v $(pwd)/data:/data ghcr.io/amrkmn/cgit:latest sh -c "cp /opt/cgit/cgitrc /data/"
```

## 3. Edit Configuration (Optional)

```bash
vim data/cgitrc
```

## 4. Start Container

```bash
docker compose up -d
```

## 5. Access

```
http://localhost:8081
```

---

## Adding Repositories

```bash
# SSH into container
docker exec -it cgit sh

# Or use the repo script
./scripts/create-repo.sh myrepo "My Repository"
```

## Adding SSH Keys

```bash
# Copy your SSH public key
cat ~/.ssh/id_rsa.pub >> data/ssh/authorized_keys

# Restart container
docker compose restart cgit
```

## Common Configuration

Edit `data/cgitrc`:

| Setting | Example | Description |
|---------|----------|-------------|
| `css` | `css=/cgit-dark.css` | Dark theme (default) |
| `snapshots` | `snapshots=tar.gz tar.bz2 zip` | Download formats |
| `readme` | `readme=:README.md` | README files to display |
| `scan-path` | `scan-path=/opt/cgit/repositories/` | Repository scan path |

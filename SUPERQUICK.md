# ⚡ Super Quick Start (2 commands!)

```bash
# 1. Copy docker-compose.yml
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml

# 2. Start container
docker compose up -d

# Done! Open http://localhost:8081
```

That's it! Just 2 commands.

## What happens automatically?

On first run, the container:
1. Creates `data/cgitrc` with default settings
2. Creates `data/repositories/` for your git repos
3. Creates `data/ssh/` for SSH keys
4. Creates `data/cache/` for cgit cache
5. Logs: `[cgit-init] ✓ Created /opt/cgit/data/cgitrc`

All data is now in one place: `./data/`!

## Customize configuration?

```bash
# Edit your configuration
vim data/cgitrc

# Restart to apply
docker compose restart cgit
```

## Directory structure after first run

```
data/
├── cgitrc           # Main configuration (edit this!)
├── repositories/     # Git repositories
├── ssh/
│   └── authorized_keys  # SSH public keys
└── cache/            # cgit cache
```

---

**That's all you need!** Just 2 commands to get started.

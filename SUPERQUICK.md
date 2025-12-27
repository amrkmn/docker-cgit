# ⚡ Super Quick Start (3 commands)

```bash
# 1. Copy docker-compose.yml
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml

# 2. Start container (cgitrc auto-created on first run!)
docker compose up -d

# Done! Open http://localhost:8081
```

That's it! No cloning, no setup scripts, no complex steps.

## What happens on first run?

The container automatically:
1. Creates `data/cgitrc` with default settings
2. Uses it to override baked-in configuration
3. Logs message: `[cgit-init] ✓ Created /opt/cgit/data/cgitrc`

## Want to customize?

```bash
# Edit your configuration
vim data/cgitrc

# Restart to apply
docker compose restart cgit
```

## Configuration files after first run

| File | Location | Description |
|------|----------|-------------|
| User config | `./data/cgitrc` | Edit this! Your custom settings |
| Defaults | (in image) | `/opt/cgit/cgitrc` - Default settings (auto-included) |

---

**That's all you need!** Just `wget`, `docker compose up -d`, done.

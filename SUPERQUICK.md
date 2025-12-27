# ⚡ Super Quick Start

Copy one file and run two commands:

```bash
# 1. Copy docker-compose.yml
wget https://raw.githubusercontent.com/amrkmn/docker-cgit/main/docker-compose.yml

# 2. Extract cgitrc from image (creates data/cgitrc)
docker run --rm -v $(pwd)/data:/data ghcr.io/amrkmn/cgit:latest sh -c "cp /opt/cgit/cgitrc /data/"

# 3. Start
docker compose up -d

# Done! Open http://localhost:8081
```

## Want to customize?

```bash
# Edit configuration
vim data/cgitrc

# Restart to apply
docker compose restart cgit
```

---

**That's it!** No cloning, no setup scripts, no complex steps.

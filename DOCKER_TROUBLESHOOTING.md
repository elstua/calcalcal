# Docker Build Issues - Quick Fixes

## Issue: "parent snapshot does not exist: not found"

This happens when Docker's build cache gets corrupted.

### Solution 1: Clean Build (Recommended)

```bash
# Stop all containers
docker-compose -f docker-compose.production.yml down

# Remove dangling images and build cache
docker system prune -f

# Rebuild from scratch (no cache)
docker-compose -f docker-compose.production.yml build --no-cache

# Start services
docker-compose -f docker-compose.production.yml up -d
```

### Solution 2: Nuclear Option (If Solution 1 Fails)

```bash
# Stop everything
docker-compose -f docker-compose.production.yml down -v

# Clean everything Docker-related
docker system prune -a -f --volumes

# Rebuild
docker-compose -f docker-compose.production.yml up -d --build
```

### Solution 3: Simplest - Just Remove Build Cache

```bash
# Clear build cache only
docker builder prune -a -f

# Rebuild
docker-compose -f docker-compose.production.yml up -d --build
```

## Common Docker Warnings

### "deploy sub-keys are not supported"

This warning is harmless. Docker Compose v2 doesn't support some v3 deploy keys in non-swarm mode. The resource limits are just ignored but everything else works fine.

To silence it, you can remove the deploy.resources.reservations sections, but it's not necessary.

## Quick Commands Reference

```bash
# View logs
docker-compose -f docker-compose.production.yml logs -f api

# Restart without rebuilding
docker-compose -f docker-compose.production.yml restart

# Check container status
docker-compose -f docker-compose.production.yml ps

# Stop everything
docker-compose -f docker-compose.production.yml down

# Start everything
docker-compose -f docker-compose.production.yml up -d

# Rebuild and start
docker-compose -f docker-compose.production.yml up -d --build

# View container resource usage
docker stats
```

## Deployment Workflow

### Normal Deployment (Code Changes):

```bash
cd /opt/calcalcal/apps/backend/node
./deploy.sh
```

### Force Rebuild (After Docker Issues):

```bash
cd /opt/calcalcal/apps/backend/node
docker-compose -f docker-compose.production.yml down
docker builder prune -a -f
docker-compose -f docker-compose.production.yml up -d --build
```

### Check Everything is Working:

```bash
# Health check
curl http://localhost:3000/health

# View logs
docker-compose -f docker-compose.production.yml logs -f

# Check both containers
docker-compose -f docker-compose.production.yml ps
```

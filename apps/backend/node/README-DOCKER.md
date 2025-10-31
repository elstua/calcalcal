# Docker Deployment Guide

This guide covers deploying the CalCalCal backend using Docker, useful for VPS deployment or local testing.

## Quick Start

### Prerequisites
- Docker installed (https://docs.docker.com/get-docker/)
- Environment variables configured (see `ENV.example`)

### Build and Run

```bash
# Build the Docker image
docker build -t calcalcal-api .

# Run with environment variables
docker run -d \
  --name calcalcal-api \
  -p 3000:3000 \
  -e DATABASE_URL="postgresql://user:pass@host:5432/db" \
  -e JWT_SECRET="your-secret-key" \
  -e OPENAI_API_KEY="sk-..." \
  -e NODE_ENV=production \
  calcalcal-api

# Check logs
docker logs calcalcal-api

# Test health endpoint
curl http://localhost:3000/health
```

### Using Docker Compose

```bash
# Copy and edit .env.local with your values
cp ENV.example .env.local

# Start services
docker-compose up -d

# View logs
docker-compose logs -f api

# Stop services
docker-compose down
```

## Resource Limits

The `docker-compose.yml` includes resource limits:
- **CPU**: 1 vCPU limit, 0.5 vCPU reserved
- **Memory**: 512MB limit, 256MB reserved

These are suitable for small VPS instances. Adjust in `docker-compose.yml` as needed.

## Production Deployment on VPS

### Step 1: Set Up VPS
```bash
# On your VPS (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### Step 2: Clone and Build
```bash
git clone https://github.com/your-username/calcalcal.git
cd calcalcal/apps/backend/node
docker build -t calcalcal-api .
```

### Step 3: Run with Production Environment
```bash
# Create .env.production file
cat > .env.production << EOF
NODE_ENV=production
DATABASE_URL=postgresql://...
JWT_SECRET=...
OPENAI_API_KEY=...
EOF

# Run container
docker run -d \
  --name calcalcal-api \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env.production \
  calcalcal-api
```

### Step 4: Set Up Reverse Proxy (Nginx)

```nginx
# /etc/nginx/sites-available/calcalcal-api
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Then enable SSL with Let's Encrypt:
```bash
sudo certbot --nginx -d your-domain.com
```

## Monitoring

```bash
# Check container status
docker ps

# View logs
docker logs -f calcalcal-api

# Check resource usage
docker stats calcalcal-api

# Restart container
docker restart calcalcal-api
```

## Troubleshooting

### Container exits immediately
- Check logs: `docker logs calcalcal-api`
- Verify environment variables are set correctly
- Ensure DATABASE_URL is accessible from container

### Out of memory errors
- Increase memory limit in docker-compose.yml
- Reduce PostgreSQL connection pool size in database.ts

### Port already in use
- Change port mapping: `-p 8080:3000` instead of `-p 3000:3000`
- Or stop existing container: `docker stop calcalcal-api`


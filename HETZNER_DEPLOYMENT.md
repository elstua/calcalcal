# Hetzner VPS Deployment Guide

This guide walks you through deploying CalCalCal backend to a Hetzner VPS using Docker.

## Prerequisites

- Hetzner VPS provisioned (recommended: CX21 - 2 vCPU, 4GB RAM)
- Domain `api.calcalcal.app` DNS pointing to your Hetzner IP
- SSH access to your VPS
- Digital Ocean environment variables (to copy over)

## Step 1: Initial VPS Setup

SSH into your Hetzner VPS and run these commands:

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
apt install docker-compose -y

# Install Nginx
apt install nginx -y

# Install Certbot for SSL
apt install certbot python3-certbot-nginx -y

# Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# Create application directory
mkdir -p /opt/calcalcal
cd /opt/calcalcal
```

## Step 2: Clone Repository

```bash
# Generate SSH key for GitHub (if needed)
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub  # Add this to GitHub deploy keys

# Clone repository
git clone git@github.com:YOUR_USERNAME/calcalcal.git /opt/calcalcal
cd /opt/calcalcal/apps/backend/node
```

## Step 3: Configure Environment Variables

Create `.env.production` from the template:

```bash
cp .env.production.template .env.production
nano .env.production  # Edit with your favorite editor
```

**Important:** Copy these values from your Digital Ocean environment:
- `JWT_SECRET`
- `OPENAI_API_KEY` or `GEMINI_API_KEY`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET`
- `R2_PUBLIC_BASE_URL`

To get Digital Ocean env vars:
```bash
# If you have DO CLI installed
doctl apps list
doctl apps env get YOUR_APP_ID
```

## Step 4: Migrate Database from Digital Ocean

### On Your Local Machine:

```bash
# Get your Digital Ocean database URL
# Go to: DigitalOcean Console → Databases → calcalcal-db → Connection Details

# Create backup
pg_dump "YOUR_DIGITAL_OCEAN_DATABASE_URL" > calcalcal_backup.sql

# Transfer to Hetzner
scp calcalcal_backup.sql root@YOUR_HETZNER_IP:/opt/calcalcal/apps/backend/node/backups/
```

### On Hetzner VPS:

```bash
cd /opt/calcalcal/apps/backend/node

# Start PostgreSQL container only
docker-compose -f docker-compose.production.yml up -d postgres

# Wait for PostgreSQL to be ready
sleep 10

# Restore database
docker exec -i calcalcal-db psql -U calcalcal calcalcal_production < backups/calcalcal_backup.sql

# Verify data
docker exec -it calcalcal-db psql -U calcalcal calcalcal_production -c "SELECT COUNT(*) FROM users;"
```

## Step 5: Start All Services

```bash
# Build and start all containers
docker-compose -f docker-compose.production.yml up -d

# Check logs
docker-compose -f docker-compose.production.yml logs -f

# Verify health
curl http://localhost:3000/health
# Should return: {"status":"ok"}
```

## Step 6: Configure Nginx

```bash
# Copy nginx configuration
cp /opt/calcalcal/nginx/calcalcal.conf /etc/nginx/sites-available/calcalcal.conf

# Create symlink
ln -s /etc/nginx/sites-available/calcalcal.conf /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx
```

## Step 7: Set Up SSL Certificate

```bash
# Obtain Let's Encrypt certificate
certbot --nginx -d api.calcalcal.app

# Follow prompts:
# - Enter your email
# - Agree to terms
# - Choose: Redirect HTTP to HTTPS (option 2)

# Test auto-renewal
certbot renew --dry-run
```

## Step 8: Verify Deployment

Test your API:

```bash
# Test health endpoint
curl https://api.calcalcal.app/health

# Test authentication endpoint
curl https://api.calcalcal.app/api/auth/status
```

## Step 9: iOS App Update

The iOS app has already been updated to use `https://api.calcalcal.app`. 

Build and test:
```bash
cd /path/to/calcalcal/ios
xcodebuild -scheme Calycal -project Calycal.xcodeproj build
```

Deploy to TestFlight for testing before releasing to App Store.

## Deployment Scripts

### Deploy Updates

```bash
cd /opt/calcalcal/apps/backend/node
chmod +x deploy.sh
./deploy.sh
```

This script:
1. Pulls latest code from GitHub
2. Builds new Docker images
3. Runs database migrations
4. Restarts containers
5. Verifies health

### Backup Database

```bash
cd /opt/calcalcal/apps/backend/node
chmod +x backup-db.sh
./backup-db.sh
```

This script:
1. Creates a PostgreSQL dump
2. Compresses it with gzip
3. Stores in `backups/` directory
4. Keeps last 7 days of backups

### Set Up Automated Daily Backups

```bash
# Add to crontab
crontab -e

# Add this line (runs daily at 2 AM):
0 2 * * * cd /opt/calcalcal/apps/backend/node && ./backup-db.sh >> /var/log/calcalcal-backup.log 2>&1
```

## Monitoring

### View Logs

```bash
# API logs
docker-compose -f docker-compose.production.yml logs -f api

# Database logs
docker-compose -f docker-compose.production.yml logs -f postgres

# Nginx logs
tail -f /var/log/nginx/calcalcal_access.log
tail -f /var/log/nginx/calcalcal_error.log
```

### Check Container Status

```bash
docker-compose -f docker-compose.production.yml ps
docker stats calcalcal-api calcalcal-db
```

### Check Disk Space

```bash
df -h
du -sh /var/lib/docker/volumes/node_postgres_data
```

## Troubleshooting

### API Container Won't Start

```bash
# Check logs
docker-compose -f docker-compose.production.yml logs api

# Common issues:
# - Missing .env.production file
# - Invalid environment variables
# - Database not ready (check postgres logs)
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker ps | grep calcalcal-db

# Test connection
docker exec -it calcalcal-db psql -U calcalcal calcalcal_production

# Check DATABASE_URL in API container
docker exec calcalcal-api env | grep DATABASE_URL
```

### SSL Certificate Issues

```bash
# Check certificate status
certbot certificates

# Renew certificate
certbot renew

# Test Nginx configuration
nginx -t
```

### Out of Memory

```bash
# Check memory usage
free -h
docker stats

# If needed, adjust resource limits in docker-compose.production.yml
# Or upgrade VPS size in Hetzner Cloud Console
```

## Rollback Procedure

If something goes wrong:

1. **Revert iOS app:**
   - Change `Configuration.swift` back to Digital Ocean URL
   - Deploy to TestFlight

2. **Point DNS back to Digital Ocean:**
   - Update A record for `api.calcalcal.app`
   - Propagation takes 5-10 minutes

3. **Restore database on Digital Ocean (if needed):**
   ```bash
   psql "DIGITAL_OCEAN_DATABASE_URL" < calcalcal_backup.sql
   ```

## Performance Tuning

### PostgreSQL

Edit `docker-compose.production.yml` and add:

```yaml
postgres:
  command: postgres -c shared_buffers=256MB -c max_connections=100
```

### API Container

Increase resource limits if needed:

```yaml
api:
  deploy:
    resources:
      limits:
        memory: 2G
```

## Security Checklist

- [ ] Firewall configured (only ports 22, 80, 443 open)
- [ ] SSH key authentication only (disable password login)
- [ ] `.env.production` not committed to git
- [ ] Database password is strong
- [ ] SSL certificate installed and auto-renewing
- [ ] Regular backups running (check crontab)
- [ ] Nginx rate limiting enabled
- [ ] Docker containers running as non-root user

## Cost Estimate

**Hetzner CX21 VPS:**
- 2 vCPU, 4GB RAM, 40GB SSD
- €5.39/month (~$6/month)

**Domain Registration:**
- ~$10-15/year

**Total:** ~$6-7/month vs $27/month on Digital Ocean

**Savings:** ~78% reduction in hosting costs

## Next Steps

After successful migration:

1. Monitor for 24-48 hours
2. Delete Digital Ocean resources (after confirming stability)
3. Set up monitoring (optional): Prometheus + Grafana
4. Configure log rotation
5. Test disaster recovery (restore from backup)

## Support

If you encounter issues:
1. Check logs (docker-compose logs, nginx logs)
2. Review this guide
3. Check Docker and Nginx documentation
4. Ask in the project repository issues

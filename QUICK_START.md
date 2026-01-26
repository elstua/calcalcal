# Quick Start: Hetzner Migration

This is a condensed checklist for migrating CalCalCal from Digital Ocean to Hetzner VPS.

## Before You Start

Have these ready:
- [ ] Hetzner VPS provisioned (CX21 or larger)
- [ ] Domain `api.calcalcal.app` DNS A record pointing to Hetzner IP
- [ ] Digital Ocean environment variables saved somewhere
- [ ] SSH access to Hetzner VPS

## On Hetzner VPS (30 minutes)

```bash
# 1. Install dependencies
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh
apt install docker-compose nginx certbot python3-certbot-nginx -y

# 2. Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# 3. Clone repository
mkdir -p /opt/calcalcal
cd /opt/calcalcal
git clone YOUR_REPO_URL .

# 4. Configure environment
cd apps/backend/node
cp .env.production.template .env.production
nano .env.production  # Fill in values from Digital Ocean
```

## Database Migration (30 minutes)

```bash
# On your local machine:
pg_dump "YOUR_DO_DATABASE_URL" > calcalcal_backup.sql
scp calcalcal_backup.sql root@YOUR_HETZNER_IP:/opt/calcalcal/apps/backend/node/backups/

# On Hetzner:
cd /opt/calcalcal/apps/backend/node
docker-compose -f docker-compose.production.yml up -d postgres
sleep 10
docker exec -i calcalcal-db psql -U calcalcal calcalcal_production < backups/calcalcal_backup.sql
```

## Start Services (15 minutes)

```bash
# Build and start
docker-compose -f docker-compose.production.yml up -d

# Verify
curl http://localhost:3000/health
# Should return: {"status":"ok"}
```

## Configure Nginx + SSL (15 minutes)

```bash
# Copy nginx config
cp /opt/calcalcal/nginx/calcalcal.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/calcalcal.conf /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# Get SSL certificate
certbot --nginx -d api.calcalcal.app

# Test
curl https://api.calcalcal.app/health
```

## Deploy iOS App (10 minutes)

The iOS app is already updated to use `https://api.calcalcal.app`.

```bash
# On your Mac
cd /path/to/calcalcal
xcodebuild -scheme Calycal -project Calycal.xcodeproj build

# Deploy to TestFlight and test
```

## Post-Migration

- [ ] Test all features (login, diary, images, AI)
- [ ] Monitor logs for 24 hours
- [ ] Set up automated backups (crontab)
- [ ] Delete Digital Ocean resources after 48 hours

## Common Commands

```bash
# View logs
docker-compose -f docker-compose.production.yml logs -f api

# Deploy updates
cd /opt/calcalcal/apps/backend/node
./deploy.sh

# Backup database
./backup-db.sh

# Restart services
docker-compose -f docker-compose.production.yml restart
```

## Troubleshooting

**API won't start?**
```bash
docker-compose -f docker-compose.production.yml logs api
# Check .env.production has all required values
```

**Database connection failed?**
```bash
docker exec -it calcalcal-db psql -U calcalcal calcalcal_production
# Verify database is accessible
```

**SSL issues?**
```bash
certbot certificates
nginx -t
```

## Rollback Plan

1. Change iOS app back to Digital Ocean URL
2. Update DNS to point to Digital Ocean
3. Wait 5-10 minutes for DNS propagation

---

**Full documentation:** See `HETZNER_DEPLOYMENT.md`

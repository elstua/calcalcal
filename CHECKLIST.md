# Pre-Migration Checklist

Use this checklist before starting the Hetzner migration.

## Prerequisites

- [ ] Hetzner account created
- [ ] Domain `calcalcal.app` registered and accessible
- [ ] SSH key generated for GitHub access
- [ ] Digital Ocean credentials backed up locally

## Information Gathering

### From Digital Ocean Dashboard

Go to Apps → calcalcal-api → Settings → Environment Variables and copy:

- [ ] `JWT_SECRET` = _______________
- [ ] `OPENAI_API_KEY` (or `GEMINI_API_KEY`) = _______________
- [ ] `AI_PROVIDER` = _______________
- [ ] `R2_ACCOUNT_ID` = _______________
- [ ] `R2_ACCESS_KEY_ID` = _______________
- [ ] `R2_SECRET_ACCESS_KEY` = _______________
- [ ] `R2_BUCKET` = _______________
- [ ] `R2_PUBLIC_BASE_URL` = _______________

### From Digital Ocean Database

Go to Databases → calcalcal-db → Connection Details:

- [ ] Database connection string saved: `postgresql://...`

### Hetzner Information

- [ ] VPS provisioned (size: ________)
- [ ] IP address: _______________
- [ ] Root password or SSH key configured

## Step 1: Commit Code Changes

```bash
cd /path/to/calcalcal
git add .
git commit -m "Prepare for Hetzner VPS migration with Docker

- Add production docker-compose with PostgreSQL
- Create deployment and backup scripts
- Add Nginx configuration for reverse proxy
- Update iOS app to use calcalcal.app domain
- Add comprehensive deployment documentation"
git push origin main
```

- [ ] Code changes committed and pushed

## Step 2: Hetzner VPS Setup

```bash
ssh root@YOUR_HETZNER_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install other tools
apt install docker-compose nginx certbot python3-certbot-nginx git -y

# Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable
```

- [ ] VPS updated
- [ ] Docker installed
- [ ] Nginx installed
- [ ] Certbot installed
- [ ] Firewall configured

## Step 3: Update DNS

Go to your domain registrar (Namecheap, GoDaddy, Cloudflare, etc.):

- [ ] Add A record: `calcalcal.app` → `YOUR_HETZNER_IP`
- [ ] Add A record: `www.calcalcal.app` → `YOUR_HETZNER_IP`
- [ ] Wait 10-30 minutes for propagation
- [ ] Test with: `dig calcalcal.app` (should show your Hetzner IP)

## Step 4: Clone Repository

```bash
# Generate SSH key on Hetzner VPS
ssh-keygen -t ed25519 -C "hetzner-vps"
cat ~/.ssh/id_ed25519.pub

# Add this key to GitHub: Settings → Deploy keys

# Clone repository
mkdir -p /opt/calcalcal
cd /opt/calcalcal
git clone git@github.com:YOUR_USERNAME/calcalcal.git .
cd apps/backend/node
```

- [ ] SSH key added to GitHub
- [ ] Repository cloned to `/opt/calcalcal`

## Step 5: Configure Environment

```bash
cd /opt/calcalcal/apps/backend/node
cp .env.production.template .env.production
nano .env.production
```

Fill in all values from Step "Information Gathering":

- [ ] `JWT_SECRET` set
- [ ] `OPENAI_API_KEY` or `GEMINI_API_KEY` set
- [ ] `AI_PROVIDER` set
- [ ] All `R2_*` variables set
- [ ] File saved

## Step 6: Database Migration

### On your local machine:

```bash
# Create backup
pg_dump "YOUR_DO_DATABASE_URL" > calcalcal_backup.sql

# Verify backup is not empty
wc -l calcalcal_backup.sql

# Transfer to Hetzner
scp calcalcal_backup.sql root@YOUR_HETZNER_IP:/opt/calcalcal/apps/backend/node/backups/
```

- [ ] Database backup created
- [ ] Backup transferred to Hetzner

### On Hetzner VPS:

```bash
cd /opt/calcalcal/apps/backend/node

# Start PostgreSQL only
docker-compose -f docker-compose.production.yml up -d postgres

# Wait for it to be ready
sleep 15

# Check if running
docker ps | grep calcalcal-db

# Restore database
docker exec -i calcalcal-db psql -U calcalcal calcalcal_production < backups/calcalcal_backup.sql

# Verify data
docker exec -it calcalcal-db psql -U calcalcal calcalcal_production -c "SELECT COUNT(*) FROM users;"
```

- [ ] PostgreSQL container started
- [ ] Database restored
- [ ] Data verified (user count matches Digital Ocean)

## Step 7: Start API

```bash
cd /opt/calcalcal/apps/backend/node

# Build and start all containers
docker-compose -f docker-compose.production.yml up -d

# Check logs
docker-compose -f docker-compose.production.yml logs -f api

# Test health endpoint (in another terminal)
curl http://localhost:3000/health
# Should return: {"status":"ok"}
```

- [ ] API container started
- [ ] Health check passes
- [ ] No errors in logs

## Step 8: Configure Nginx

```bash
# Copy configuration
cp /opt/calcalcal/nginx/calcalcal.conf /etc/nginx/sites-available/

# Create symlink
ln -s /etc/nginx/sites-available/calcalcal.conf /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Check status
systemctl status nginx
```

- [ ] Nginx config copied
- [ ] Config test passed
- [ ] Nginx restarted successfully

## Step 9: SSL Certificate

```bash
# Obtain certificate (follow prompts)
certbot --nginx -d calcalcal.app -d www.calcalcal.app

# Test renewal
certbot renew --dry-run
```

- [ ] Certificate obtained
- [ ] Auto-renewal configured
- [ ] HTTPS works: `curl https://calcalcal.app/health`

## Step 10: Test API Endpoints

```bash
# Health check
curl https://calcalcal.app/health

# Auth status
curl https://calcalcal.app/api/auth/status

# Test from your local machine too
curl https://calcalcal.app/health
```

- [ ] Health endpoint works
- [ ] Auth endpoint works
- [ ] Accessible from outside the VPS

## Step 11: iOS App Testing

### Build and test:

```bash
cd /path/to/calcalcal
xcodebuild -scheme Calycal -project Calycal.xcodeproj build
```

- [ ] iOS project builds successfully
- [ ] Test in Xcode simulator
- [ ] Test login/signup
- [ ] Test creating diary entry
- [ ] Test image upload
- [ ] Test AI analysis

## Step 12: Deploy to TestFlight

- [ ] Archive app in Xcode
- [ ] Upload to App Store Connect
- [ ] Deploy to TestFlight
- [ ] Test with real device
- [ ] Verify all features work

## Step 13: Set Up Automated Backups

```bash
cd /opt/calcalcal/apps/backend/node
chmod +x backup-db.sh

# Test backup
./backup-db.sh

# Add to crontab
crontab -e
# Add this line:
# 0 2 * * * cd /opt/calcalcal/apps/backend/node && ./backup-db.sh >> /var/log/calcalcal-backup.log 2>&1
```

- [ ] Backup script tested
- [ ] Cron job configured
- [ ] Backup works

## Step 14: Monitor for 24-48 Hours

- [ ] Check logs regularly: `docker-compose -f docker-compose.production.yml logs -f`
- [ ] Monitor disk space: `df -h`
- [ ] Check memory usage: `free -h`
- [ ] Test all app features multiple times
- [ ] No critical errors

## Step 15: Clean Up Digital Ocean

**ONLY after confirming everything works!**

- [ ] App stable for 24-48 hours
- [ ] All features tested and working
- [ ] Backups working on Hetzner
- [ ] Ready to delete Digital Ocean resources

Go to Digital Ocean Dashboard:

- [ ] Delete App Platform app (saves $12/month)
- [ ] Delete managed database (saves $15/month)
- [ ] Keep domain if registered there, or transfer to another registrar

## Post-Migration Tasks

- [ ] Document server access details securely
- [ ] Share new infrastructure details with team (if any)
- [ ] Update any external documentation
- [ ] Set up monitoring (optional: Grafana)
- [ ] Test disaster recovery (restore from backup)

---

## Quick Reference

### Important Files
- Deployment guide: `HETZNER_DEPLOYMENT.md`
- Quick start: `QUICK_START.md`
- Summary: `MIGRATION_SUMMARY.md`
- Nginx config: `nginx/calcalcal.conf`
- Docker compose: `apps/backend/node/docker-compose.production.yml`

### Important Commands

**View logs:**
```bash
docker-compose -f docker-compose.production.yml logs -f api
```

**Restart services:**
```bash
docker-compose -f docker-compose.production.yml restart
```

**Deploy updates:**
```bash
./deploy.sh
```

**Backup database:**
```bash
./backup-db.sh
```

**Check container status:**
```bash
docker-compose -f docker-compose.production.yml ps
docker stats
```

### Important Credentials

**Database:**
- Host: `postgres` (inside Docker network) or `localhost` (from VPS)
- Port: `5432`
- Database: `calcalcal_production`
- User: `calcalcal`
- Password: `NeonGenezisEva02!`

**API:**
- Internal: `http://localhost:3000`
- External: `https://calcalcal.app`

---

**Estimated Total Time:** 2.5 - 3 hours
**Estimated Cost Savings:** $21/month (78% reduction)

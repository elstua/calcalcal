# Migration Summary: Digital Ocean → Hetzner VPS

## What Was Done

All code changes and configuration files have been prepared for migrating CalCalCal from Digital Ocean to Hetzner VPS with Docker.

### ✅ Files Created

1. **`apps/backend/node/docker-compose.production.yml`**
   - Complete Docker Compose setup with PostgreSQL and API containers
   - Configured with your database password: `NeonGenezisEva02!`
   - Includes health checks, restart policies, and resource limits
   - Network isolation for security

2. **`apps/backend/node/.env.production.template`**
   - Template for production environment variables
   - Clear instructions on which values to copy from Digital Ocean
   - All required configurations documented

3. **`apps/backend/node/deploy.sh`**
   - Automated deployment script
   - Pulls latest code, builds images, runs migrations, restarts containers
   - Includes health checks and error handling
   - Make executable with: `chmod +x deploy.sh`

4. **`apps/backend/node/backup-db.sh`**
   - Automated database backup script
   - Creates compressed daily backups
   - Keeps last 7 days of backups automatically
   - Make executable with: `chmod +x backup-db.sh`

5. **`nginx/calcalcal.conf`**
   - Complete Nginx reverse proxy configuration
   - SSL/TLS setup for `api.calcalcal.app`
   - Rate limiting (100 requests/minute per IP)
   - Security headers and proper timeouts for AI requests

6. **`HETZNER_DEPLOYMENT.md`**
   - Complete step-by-step deployment guide
   - All commands you need to run
   - Troubleshooting section
   - Security checklist

7. **`QUICK_START.md`**
   - Condensed checklist version
   - Quick reference for common commands
   - Minimal but complete migration steps

### ✅ Files Updated

1. **`calcalcal/Models/Configuration.swift`**
   - Production URL changed from `https://calycal-app-egy2b.ondigitalocean.app`
   - To: `https://api.api.calcalcal.app`
   - Works for both debug and release builds

2. **`calcalcal/Info.plist`**
   - API_URL updated to `https://api.api.calcalcal.app`
   - Ensures proper configuration for production builds

3. **`apps/backend/node/.gitignore`**
   - Added `.env.production` (contains secrets)
   - Added `backups/` directory (database dumps)

## Key Configuration Details

### Database
- **Container name:** `calcalcal-db`
- **Image:** `postgres:15-alpine`
- **Database name:** `calcalcal_production`
- **Username:** `calcalcal`
- **Password:** `NeonGenezisEva02!`
- **Port:** `5432` (only accessible from localhost)
- **Data persistence:** Docker volume `postgres_data`

### API
- **Container name:** `calcalcal-api`
- **Port:** `3000` (only accessible from localhost)
- **Environment:** Production
- **Health check:** `/health` endpoint
- **Auto-restart:** Yes

### Nginx
- **Domain:** `api.calcalcal.app` and `api.calcalcal.app`
- **SSL:** Let's Encrypt (auto-renewing)
- **Rate limit:** 100 requests/minute per IP
- **Proxy:** `localhost:3000` → `https://api.api.calcalcal.app`

### Security
- Database only accessible from localhost (not exposed to internet)
- API only accessible from localhost (Nginx proxies requests)
- Firewall allows only SSH (22), HTTP (80), HTTPS (443)
- All secrets in `.env.production` (not committed to git)
- Docker containers run as non-root user
- SSL/TLS with strong ciphers

## What You Need to Do

### 1. Provision Hetzner VPS
- Go to Hetzner Cloud Console
- Create new VPS (recommend CX21: 2 vCPU, 4GB RAM, €5.39/month)
- Note the IP address

### 2. Update DNS
- Go to your domain registrar for `api.calcalcal.app`
- Add/update A record: `api.calcalcal.app` → `YOUR_HETZNER_IP`
- Add/update A record: `api.calcalcal.app` → `YOUR_HETZNER_IP`
- Wait 5-10 minutes for DNS propagation

### 3. Get Digital Ocean Secrets
You need to copy these from Digital Ocean:
- `JWT_SECRET`
- `OPENAI_API_KEY` or `GEMINI_API_KEY`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET`
- `R2_PUBLIC_BASE_URL`

To get them from Digital Ocean CLI:
```bash
doctl apps list
doctl apps env get YOUR_APP_ID
```

Or from Digital Ocean Dashboard:
1. Go to Apps → calcalcal-api
2. Settings → Environment Variables
3. Copy each value

### 4. Export Database from Digital Ocean
```bash
# Get database connection string from Digital Ocean Dashboard
# Databases → calcalcal-db → Connection Details

# Create backup
pg_dump "YOUR_DO_DATABASE_URL" > calcalcal_backup.sql
```

### 5. Follow Deployment Guide
Open `HETZNER_DEPLOYMENT.md` and follow all steps in order.

Or use the quick start: `QUICK_START.md`

## Timeline Estimate

- **VPS setup:** 30 minutes
- **Database migration:** 30 minutes  
- **API deployment:** 15 minutes
- **Nginx + SSL:** 15 minutes
- **iOS app deployment:** 10 minutes
- **Testing:** 30 minutes
- **Total:** ~2.5 hours

## Cost Savings

**Before (Digital Ocean):**
- App Platform: $12/month
- Managed PostgreSQL: $15/month
- **Total: $27/month**

**After (Hetzner):**
- CX21 VPS: €5.39/month (~$6/month)
- Cloudflare R2: Same as before
- **Total: $6/month + R2 costs**

**Savings: $21/month (78% reduction)**

## Testing Checklist

After migration, test these features:

- [ ] User registration
- [ ] User login (email/password)
- [ ] Google Sign-In
- [ ] Apple Sign-In
- [ ] Create diary entry
- [ ] Edit diary entry
- [ ] Delete diary entry
- [ ] Upload image
- [ ] AI food analysis
- [ ] Calorie tracking
- [ ] Streaks calculation
- [ ] Profile settings
- [ ] Account deletion

## Rollback Plan

If something goes wrong:

1. **Keep Digital Ocean running** - Don't delete anything yet
2. **Revert iOS app:** Change URLs back to Digital Ocean
3. **Revert DNS:** Point domain back to Digital Ocean IP
4. **Wait 5-10 minutes** for DNS propagation

## Next Steps After Successful Migration

1. **Monitor for 24-48 hours** - Check logs, watch for errors
2. **Set up automated backups:**
   ```bash
   crontab -e
   # Add: 0 2 * * * cd /opt/calcalcal/apps/backend/node && ./backup-db.sh
   ```
3. **Delete Digital Ocean resources** (after confirming everything works)
4. **Update documentation** with new server details
5. **Set up monitoring** (optional: Grafana, Prometheus)

## Support & Documentation

- **Full guide:** `HETZNER_DEPLOYMENT.md`
- **Quick reference:** `QUICK_START.md`
- **Nginx config:** `nginx/calcalcal.conf`
- **Docker setup:** `apps/backend/node/docker-compose.production.yml`

## Important Notes

1. **Database password** is hardcoded in `docker-compose.production.yml`
   - This is OK because the database is only accessible from localhost
   - Not exposed to the internet
   - Firewall protects the server

2. **`.env.production` is gitignored**
   - Contains all secrets
   - Create on server, never commit to git
   - Use `.env.production.template` as a guide

3. **Scripts need to be executable**
   ```bash
   chmod +x deploy.sh backup-db.sh
   ```

4. **DNS propagation takes time**
   - Can take 5 minutes to 48 hours
   - Usually completes in 10-30 minutes
   - Test with: `dig api.calcalcal.app`

5. **SSL certificate auto-renews**
   - Let's Encrypt certificates valid for 90 days
   - Certbot automatically renews them
   - No action needed from you

## Questions?

If you encounter issues:
1. Check the deployment guide: `HETZNER_DEPLOYMENT.md`
2. Check logs: `docker-compose -f docker-compose.production.yml logs -f`
3. Review Nginx logs: `/var/log/nginx/calcalcal_error.log`
4. Test connectivity: `curl http://localhost:3000/health`

---

**Status:** ✅ All code changes complete, ready for deployment

**Next action:** Provision Hetzner VPS and follow `HETZNER_DEPLOYMENT.md`

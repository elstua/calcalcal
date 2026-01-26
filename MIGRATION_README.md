# CalCalCal Hetzner Migration

This directory contains all files and documentation needed to migrate CalCalCal from Digital Ocean to Hetzner VPS with Docker.

## 📚 Documentation Files

### Start Here
- **[CHECKLIST.md](CHECKLIST.md)** - Complete step-by-step checklist with checkboxes
- **[QUICK_START.md](QUICK_START.md)** - Condensed version for experienced users

### Detailed Guides  
- **[HETZNER_DEPLOYMENT.md](HETZNER_DEPLOYMENT.md)** - Full deployment guide with all commands
- **[MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md)** - Overview of what was changed and why

## 🗂️ New Files Created

### Backend Configuration
```
apps/backend/node/
├── docker-compose.production.yml  # Production Docker setup with PostgreSQL
├── .env.production.template       # Template for environment variables
├── deploy.sh                      # Automated deployment script
└── backup-db.sh                   # Database backup script
```

### Nginx Configuration
```
nginx/
└── calcalcal.conf                 # Reverse proxy configuration for api.calcalcal.app
```

### iOS App Updates
```
calcalcal/
├── Models/Configuration.swift     # Updated to use https://api.api.calcalcal.app
└── Info.plist                     # Updated API_URL to https://api.api.calcalcal.app
```

## 🚀 Quick Start

1. **Read the checklist:** [CHECKLIST.md](CHECKLIST.md)
2. **Provision Hetzner VPS:** CX21 (2 vCPU, 4GB RAM) recommended
3. **Update DNS:** Point `api.calcalcal.app` to your Hetzner IP
4. **Follow the guide:** Complete all steps in [HETZNER_DEPLOYMENT.md](HETZNER_DEPLOYMENT.md)

## ⏱️ Time Estimate

- VPS setup: 30 minutes
- Database setup: 5 minutes (fresh start!)
- API deployment: 15 minutes
- Nginx + SSL: 15 minutes
- iOS app update: 10 minutes
- Testing: 30 minutes (with new test accounts)
- **Total: ~2 hours (faster with fresh database!)**

## 💰 Cost Savings

**Digital Ocean (Current):**
- App Platform: $12/month
- Managed PostgreSQL: $15/month
- **Total: $27/month**

**Hetzner (New):**
- CX21 VPS: €5.39/month (~$6/month)
- **Total: $6/month**

**Savings: $21/month (78% reduction)**

## 🔑 Key Information

### Database Configuration
- Container: `calcalcal-db`
- Database: `calcalcal_production`
- User: `calcalcal`
- Password: `NeonGenezisEva02!`
- Port: `5432` (localhost only)

### API Configuration
- Container: `calcalcal-api`
- Port: `3000` (localhost only)
- Domain: `https://api.api.calcalcal.app`
- Health endpoint: `https://api.api.calcalcal.app/health`

### SSL Configuration
- Provider: Let's Encrypt (free, auto-renewing)
- Domains: `api.calcalcal.app` and `api.calcalcal.app`

## 🔒 Security Features

✅ Database only accessible from localhost  
✅ API only accessible from localhost (Nginx proxies)  
✅ Firewall: Only ports 22, 80, 443 open  
✅ SSL/TLS encryption with strong ciphers  
✅ Rate limiting: 100 requests/minute per IP  
✅ Docker containers run as non-root user  
✅ Secrets in `.env.production` (gitignored)  

## 📊 Architecture

```
Internet → Nginx (443) → API Container (3000)
                              ↓
                         PostgreSQL Container (5432)
                              ↓
                         Docker Volume (postgres_data)
```

**All container communication is isolated in a Docker network.**

## 🛠️ Common Commands

### View logs
```bash
cd /opt/calcalcal/apps/backend/node
docker-compose -f docker-compose.production.yml logs -f api
```

### Restart services
```bash
docker-compose -f docker-compose.production.yml restart
```

### Deploy updates
```bash
./deploy.sh
```

### Backup database
```bash
./backup-db.sh
```

### Check status
```bash
docker-compose -f docker-compose.production.yml ps
```

## ⚠️ Important Notes

1. **Don't delete Digital Ocean yet**
   - Keep it running for 24-48 hours after migration
   - Use as backup if something goes wrong
   - Only delete after confirming everything works

2. **DNS propagation takes time**
   - Usually 10-30 minutes
   - Can take up to 48 hours in rare cases
   - Test with: `dig api.calcalcal.app`

3. **Test everything**
   - User registration/login
   - Creating diary entries
   - Image uploads
   - AI food analysis
   - All app features

4. **Set up automated backups**
   - Add cron job for daily database backups
   - Keep backups for at least 7 days
   - Test restore procedure

## 🆘 Troubleshooting

### API won't start
```bash
docker-compose -f docker-compose.production.yml logs api
# Check .env.production has all required values
```

### Database connection failed
```bash
docker exec -it calcalcal-db psql -U calcalcal calcalcal_production
# Verify database is accessible
```

### SSL certificate issues
```bash
certbot certificates
nginx -t
systemctl restart nginx
```

### Out of memory
```bash
docker stats
free -h
# Consider upgrading VPS or adjusting resource limits
```

## 🔄 Rollback Plan

If migration fails:

1. Revert iOS app URL in `Configuration.swift`
2. Update DNS to point back to Digital Ocean
3. Wait 5-10 minutes for DNS propagation
4. Everything back to normal

## 📝 Post-Migration Checklist

After successful migration:

- [ ] Monitor logs for 24 hours
- [ ] Test all app features
- [ ] Set up automated backups (cron)
- [ ] Document server access
- [ ] Test disaster recovery
- [ ] Delete Digital Ocean resources (after 48 hours)
- [ ] Update team documentation
- [ ] Celebrate saving $252/year! 🎉

## 📧 Support

If you encounter issues:

1. Check logs: `docker-compose logs -f`
2. Review [HETZNER_DEPLOYMENT.md](HETZNER_DEPLOYMENT.md) troubleshooting section
3. Check [CHECKLIST.md](CHECKLIST.md) for missed steps
4. Review Nginx logs: `/var/log/nginx/calcalcal_error.log`

## 🎯 What's Next

After stable migration:

- Monitor resource usage
- Tune PostgreSQL for better performance
- Consider adding Prometheus + Grafana for monitoring
- Set up log rotation
- Consider adding CDN for static assets
- Plan for horizontal scaling (if needed in future)

---

**Status:** ✅ Ready for deployment  
**Last Updated:** January 26, 2026  
**Domain:** api.calcalcal.app  
**Database Password:** NeonGenezisEva02!

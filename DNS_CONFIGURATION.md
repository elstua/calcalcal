# DNS Configuration for Hetzner Migration

## Current Setup

Your domain is configured with an **API subdomain**, which is the recommended best practice.

### DNS Record
- **Type:** A Record
- **Name:** `api`
- **Domain:** `api.calcalcal.app`
- **Points to:** Your Hetzner VPS IP address

## Why This Is Better

Using `api.calcalcal.app` instead of just `calcalcal.app` offers several advantages:

1. **Separation of Concerns**
   - Main website can be at `calcalcal.app` (future)
   - API stays at `api.calcalcal.app`
   - Each can be hosted separately if needed

2. **Professional Standard**
   - Industry standard practice
   - Clear purpose in the URL
   - Easier to manage multiple services

3. **Flexibility**
   - Can add more subdomains: `admin.calcalcal.app`, `beta.api.calcalcal.app`, etc.
   - Can move API to different server without affecting main domain
   - Can add CDN or load balancer later

4. **Security**
   - Separate SSL certificates if needed
   - Can apply different security policies
   - Easier to isolate in case of issues

## What Changed

All configuration files have been updated to use `api.calcalcal.app`:

### iOS App
- **Configuration.swift:** `https://api.calcalcal.app`
- **Info.plist:** `https://api.calcalcal.app`

### Backend
- **Nginx config:** `server_name api.calcalcal.app`
- **SSL certificates:** `/etc/letsencrypt/live/api.calcalcal.app/`
- **.env.production.template:** `PUBLIC_BASE_URL=https://api.calcalcal.app`

### Documentation
All markdown files updated to reference `api.calcalcal.app`

## SSL Certificate Command

When setting up SSL, use:

```bash
certbot --nginx -d api.calcalcal.app
```

**Note:** You don't need `www.api.calcalcal.app` - the www prefix is only for main domains, not subdomains.

## Testing Your DNS

Verify your DNS is correctly pointing to Hetzner:

```bash
# Check DNS resolution
dig api.calcalcal.app

# Should return your Hetzner IP in the ANSWER section
# Example output:
# api.calcalcal.app.  300  IN  A  YOUR_HETZNER_IP
```

Also test with:

```bash
# From any computer
nslookup api.calcalcal.app

# Or check online
# Visit: https://dnschecker.org/#A/api.calcalcal.app
```

## What You DON'T Need

- ❌ No need for `www.api.calcalcal.app` DNS record
- ❌ No need for root domain `calcalcal.app` to point to Hetzner (unless you want a website there)
- ❌ No need for `www.calcalcal.app` DNS record (for the API)

## Future Possibilities

With this setup, you can easily add:

- **Main Website:** `calcalcal.app` → Different server or static hosting
- **Admin Panel:** `admin.calcalcal.app` → Admin interface
- **Staging API:** `staging.api.calcalcal.app` → Test environment
- **Beta API:** `beta.api.calcalcal.app` → Beta features
- **CDN:** Add CloudFlare or similar in front of `api.calcalcal.app`

## Summary

✅ **Current DNS:** `api.calcalcal.app` → Hetzner VPS  
✅ **iOS app configured:** Uses `https://api.calcalcal.app`  
✅ **Nginx configured:** Serves `api.calcalcal.app`  
✅ **SSL setup:** For `api.calcalcal.app`  
✅ **Professional setup:** Industry best practice  

You're all set! This is the right way to do it. 🎉

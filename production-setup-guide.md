# Twenty CRM Production Setup Guide

## 🎯 Overview
This guide will help you deploy Twenty CRM to production on your Hostinger VPS at `twenty.ignitabull.org`.

## ✅ Prerequisites Completed
- [x] Local development environment working
- [x] Hostinger VPS configured (193.203.167.44)
- [x] Domain `twenty.ignitabull.org` DNS configured
- [x] Production environment files created
- [x] Secure secrets generated
- [x] Deployment script prepared

## 🚀 Deployment Steps

### 1. Connect to Your VPS
```bash
ssh root@193.203.167.44
# or
ssh your_username@193.203.167.44
```

### 2. Upload Configuration Files
From your local machine, upload the necessary files:
```bash
# Upload deployment script
scp deploy-twenty.sh root@193.203.167.44:/tmp/

# Upload environment files
scp packages/twenty-server/.env.prod root@193.203.167.44:/tmp/twenty-server.env
scp packages/twenty-front/.env.prod root@193.203.167.44:/tmp/twenty-front.env
```

### 3. Run Deployment Script
On the server:
```bash
cd /tmp
chmod +x deploy-twenty.sh
./deploy-twenty.sh
```

## 📧 SMTP Configuration

### Option 1: Amazon SES (Recommended - Already configured)
Your domain `ignitabull.org` already has Amazon SES configured. Update these values in your production environment:

```env
EMAIL_SMTP_HOST=email-smtp.us-east-1.amazonaws.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_SECURE=false
EMAIL_SMTP_AUTH_USER=your_ses_access_key_here
EMAIL_SMTP_AUTH_PASSWORD=your_ses_secret_key_here
```

### Option 2: Gmail SMTP (Alternative)
```env
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_SECURE=false
EMAIL_SMTP_AUTH_USER=your_gmail@gmail.com
EMAIL_SMTP_AUTH_PASSWORD=your_app_password
```

### Option 3: Hostinger Email (Built-in)
```env
EMAIL_SMTP_HOST=smtp.hostinger.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_SECURE=false
EMAIL_SMTP_AUTH_USER=noreply@ignitabull.org
EMAIL_SMTP_AUTH_PASSWORD=your_email_password
```

## 🔧 Post-Deployment Configuration

### 1. Access Your CRM
Visit: **https://twenty.ignitabull.org**

### 2. Initial Setup
1. Create your first workspace
2. Add your first user account
3. Configure company settings
4. Set up email templates

### 3. Service Management
```bash
# Check service status
pm2 status

# View logs
pm2 logs

# Restart services
pm2 restart all

# Monitor services
pm2 monit
```

### 4. Nginx Management
```bash
# Check nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx
```

### 5. Database Management
```bash
# Connect to database
sudo -u postgres psql twenty_prod

# Backup database
sudo -u postgres pg_dump twenty_prod > /backup/twenty_$(date +%Y%m%d).sql

# Restore database
sudo -u postgres psql twenty_prod < /backup/twenty_backup.sql
```

## 🔒 Security Checklist

### SSL Certificate
- [x] Let's Encrypt certificate configured
- [x] Auto-renewal enabled
- [x] HTTPS redirect configured

### Firewall
- [x] UFW firewall enabled
- [x] SSH access allowed
- [x] HTTP/HTTPS access allowed
- [x] Database ports restricted

### Application Security
- [x] Secure secrets generated
- [x] Environment variables protected
- [x] Application user with limited privileges
- [x] Security headers configured in Nginx

## 📊 Monitoring & Maintenance

### 1. Log Files
- Application logs: `pm2 logs`
- Nginx logs: `/var/log/nginx/`
- PostgreSQL logs: `/var/log/postgresql/`

### 2. Health Checks
- Application health: `https://twenty.ignitabull.org/healthz`
- Database connection: `pm2 logs twenty-backend`
- SSL certificate: `sudo certbot certificates`

### 3. Backup Strategy
```bash
# Create backup script
sudo crontab -e

# Add daily backup (2 AM)
0 2 * * * /usr/local/bin/backup-twenty.sh
```

### 4. Updates
```bash
# Update application
cd /var/www/twenty
sudo -u twenty git pull origin main
sudo -u twenty yarn install
sudo -u twenty yarn build
pm2 restart all
```

## 🔗 Integrations Setup

### Webhooks
Configure webhooks at: `https://twenty.ignitabull.org/webhooks/workflows/`

### API Access
- GraphQL Playground: `https://twenty.ignitabull.org/graphql`
- REST API: `https://twenty.ignitabull.org/rest/`
- OpenAPI Docs: `https://twenty.ignitabull.org/open-api/core`

### Slack Integration (Optional)
1. Create Slack app at https://api.slack.com/apps
2. Configure OAuth & Permissions
3. Add webhook URL: `https://twenty.ignitabull.org/webhooks/slack`

## 🆘 Troubleshooting

### Common Issues
1. **Port conflicts**: Check with `sudo lsof -i :3000,3001`
2. **Database connection**: Check PostgreSQL service status
3. **Memory issues**: Monitor with `htop` and increase if needed
4. **SSL issues**: Check certificate with `sudo certbot certificates`

### Emergency Procedures
```bash
# Stop all services
pm2 stop all
sudo systemctl stop nginx

# Start in safe mode
pm2 start twenty-backend --watch
pm2 start twenty-frontend --watch
```

## 📞 Support
- GitHub Issues: https://github.com/twentyhq/twenty/issues
- Discord: Twenty Community Discord
- Documentation: https://twenty.com/developers

---

🎉 **Congratulations!** Your Twenty CRM should now be running in production at `https://twenty.ignitabull.org` 
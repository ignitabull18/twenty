#!/bin/bash

# Twenty CRM Production Deployment Script
# Domain: twenty.ignitabull.org
# Server: 193.203.167.44

set -e  # Exit on any error

echo "🚀 Starting Twenty CRM Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="twenty.ignitabull.org"
SERVER_IP="193.203.167.44"
APP_DIR="/var/www/twenty"
SERVICE_USER="twenty"
NODE_VERSION="22.12.0"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for safety"
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    
    # Install required packages
    sudo apt install -y \
        nginx \
        postgresql \
        postgresql-contrib \
        redis-server \
        certbot \
        python3-certbot-nginx \
        git \
        curl \
        build-essential \
        systemd \
        ufw
        
    print_success "System dependencies installed"
}

# Install Node.js with fnm
install_nodejs() {
    print_status "Installing Node.js $NODE_VERSION with fnm..."
    
    # Install fnm if not exists
    if ! command -v fnm &> /dev/null; then
        curl -fsSL https://fnm.vercel.app/install | bash
        export PATH=$PATH:$HOME/.fnm
        eval "$(fnm env)"
    fi
    
    # Install and use Node.js
    fnm install $NODE_VERSION
    fnm use $NODE_VERSION
    fnm default $NODE_VERSION
    
    # Install global packages
    npm install -g yarn pm2
    
    print_success "Node.js $NODE_VERSION installed"
}

# Setup PostgreSQL
setup_database() {
    print_status "Setting up PostgreSQL database..."
    
    sudo -u postgres psql -c "CREATE DATABASE twenty_prod;" 2>/dev/null || print_warning "Database may already exist"
    sudo -u postgres psql -c "CREATE USER twenty WITH ENCRYPTED PASSWORD 'twenty_secure_password';" 2>/dev/null || print_warning "User may already exist"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE twenty_prod TO twenty;"
    
    print_success "Database configured"
}

# Setup application user
setup_user() {
    print_status "Setting up application user..."
    
    sudo useradd -m -s /bin/bash $SERVICE_USER 2>/dev/null || print_warning "User may already exist"
    sudo mkdir -p $APP_DIR
    sudo chown $SERVICE_USER:$SERVICE_USER $APP_DIR
    
    print_success "Application user configured"
}

# Deploy application
deploy_app() {
    print_status "Deploying Twenty application..."
    
    # Clone or update repository
    if [ -d "$APP_DIR/.git" ]; then
        cd $APP_DIR
        sudo -u $SERVICE_USER git pull origin main
    else
        sudo -u $SERVICE_USER git clone https://github.com/twentyhq/twenty.git $APP_DIR
        cd $APP_DIR
    fi
    
    # Copy production environment files
    sudo -u $SERVICE_USER cp packages/twenty-server/.env.prod packages/twenty-server/.env
    sudo -u $SERVICE_USER cp packages/twenty-front/.env.prod packages/twenty-front/.env
    
    # Install dependencies with increased memory
    sudo -u $SERVICE_USER bash -c "
        export NODE_OPTIONS='--max-old-space-size=8192'
        eval \"\$(fnm env)\"
        fnm use $NODE_VERSION
        yarn install --frozen-lockfile
    "
    
    # Build application
    sudo -u $SERVICE_USER bash -c "
        export NODE_OPTIONS='--max-old-space-size=8192'
        eval \"\$(fnm env)\"
        fnm use $NODE_VERSION
        yarn build
    "
    
    # Initialize database
    sudo -u $SERVICE_USER bash -c "
        export NODE_OPTIONS='--max-old-space-size=8192'
        eval \"\$(fnm env)\"
        fnm use $NODE_VERSION
        cd packages/twenty-server
        npx nx run twenty-server:database:init:prod
    "
    
    print_success "Application deployed"
}

# Setup SSL certificate
setup_ssl() {
    print_status "Setting up SSL certificate..."
    
    # Stop nginx if running
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Get certificate
    sudo certbot certonly \
        --standalone \
        --email support@ignitabull.org \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN
    
    print_success "SSL certificate configured"
}

# Setup Nginx
setup_nginx() {
    print_status "Setting up Nginx configuration..."
    
    sudo tee /etc/nginx/sites-available/twenty > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Frontend
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend API
    location /graphql {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend routes
    location ~ ^/(auth|webhooks|files|client-config|healthz|rest|metadata) {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/twenty /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test and start nginx
    sudo nginx -t
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    print_success "Nginx configured"
}

# Setup PM2 services
setup_services() {
    print_status "Setting up PM2 services..."
    
    sudo -u $SERVICE_USER bash -c "
        eval \"\$(fnm env)\"
        fnm use $NODE_VERSION
        cd $APP_DIR
        
        # Backend service
        pm2 start 'NODE_OPTIONS=\"--max-old-space-size=8192\" npx nx start twenty-server' --name twenty-backend
        
        # Frontend service  
        pm2 start 'NODE_OPTIONS=\"--max-old-space-size=8192\" npx nx start twenty-front' --name twenty-frontend
        
        # Save PM2 configuration
        pm2 save
        pm2 startup
    "
    
    print_success "PM2 services configured"
}

# Setup firewall
setup_firewall() {
    print_status "Setting up firewall..."
    
    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow 'Nginx Full'
    sudo ufw allow 5432  # PostgreSQL
    sudo ufw allow 6379  # Redis
    
    print_success "Firewall configured"
}

# Main deployment function
main() {
    print_status "Starting Twenty CRM deployment to $DOMAIN"
    
    check_root
    install_dependencies
    install_nodejs
    setup_database
    setup_user
    deploy_app
    setup_ssl
    setup_nginx
    setup_services
    setup_firewall
    
    print_success "🎉 Twenty CRM deployment completed!"
    print_success "Access your CRM at: https://$DOMAIN"
    print_status "Useful commands:"
    echo "  - Check services: pm2 status"
    echo "  - View logs: pm2 logs"
    echo "  - Restart services: pm2 restart all"
    echo "  - Update SSL: sudo certbot renew"
}

# Run main function
main "$@" 
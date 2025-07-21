#!/bin/bash

# Twenty CRM Backup Script
# Backs up database, files, and configuration

set -e

# Configuration
BACKUP_DIR="/backup/twenty"
APP_DIR="/var/www/twenty"
DB_NAME="twenty_prod"
DB_USER="postgres"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[BACKUP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    print_status "Created backup directory: $BACKUP_DIR"
}

# Backup database
backup_database() {
    print_status "Backing up database..."
    
    sudo -u postgres pg_dump "$DB_NAME" | gzip > "$BACKUP_DIR/database_$DATE.sql.gz"
    
    if [ $? -eq 0 ]; then
        print_success "Database backup completed: database_$DATE.sql.gz"
    else
        print_error "Database backup failed!"
        exit 1
    fi
}

# Backup uploaded files
backup_files() {
    print_status "Backing up uploaded files..."
    
    if [ -d "$APP_DIR/.local-storage" ]; then
        tar -czf "$BACKUP_DIR/files_$DATE.tar.gz" -C "$APP_DIR" .local-storage
        print_success "Files backup completed: files_$DATE.tar.gz"
    else
        print_status "No files to backup (.local-storage not found)"
    fi
}

# Backup configuration
backup_config() {
    print_status "Backing up configuration..."
    
    mkdir -p "$BACKUP_DIR/config_$DATE"
    
    # Copy environment files
    if [ -f "$APP_DIR/packages/twenty-server/.env" ]; then
        cp "$APP_DIR/packages/twenty-server/.env" "$BACKUP_DIR/config_$DATE/server.env"
    fi
    
    if [ -f "$APP_DIR/packages/twenty-front/.env" ]; then
        cp "$APP_DIR/packages/twenty-front/.env" "$BACKUP_DIR/config_$DATE/frontend.env"
    fi
    
    # Copy nginx configuration
    if [ -f "/etc/nginx/sites-available/twenty" ]; then
        cp "/etc/nginx/sites-available/twenty" "$BACKUP_DIR/config_$DATE/nginx.conf"
    fi
    
    # Copy PM2 ecosystem
    sudo -u twenty pm2 save || true
    if [ -f "/home/twenty/.pm2/dump.pm2" ]; then
        cp "/home/twenty/.pm2/dump.pm2" "$BACKUP_DIR/config_$DATE/pm2.dump"
    fi
    
    tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C "$BACKUP_DIR" "config_$DATE"
    rm -rf "$BACKUP_DIR/config_$DATE"
    
    print_success "Configuration backup completed: config_$DATE.tar.gz"
}

# Clean old backups
cleanup_old_backups() {
    print_status "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_DIR" -type f -name "*.gz" -mtime +$RETENTION_DAYS -delete
    
    print_success "Old backups cleaned up"
}

# Create backup summary
create_summary() {
    print_status "Creating backup summary..."
    
    cat > "$BACKUP_DIR/backup_$DATE.log" <<EOF
Twenty CRM Backup Summary
========================
Date: $(date)
Server: $(hostname)
Database: $DB_NAME

Files backed up:
- Database: database_$DATE.sql.gz ($(du -h "$BACKUP_DIR/database_$DATE.sql.gz" | cut -f1))
- Files: files_$DATE.tar.gz ($(du -h "$BACKUP_DIR/files_$DATE.tar.gz" 2>/dev/null | cut -f1 || echo "N/A"))
- Config: config_$DATE.tar.gz ($(du -h "$BACKUP_DIR/config_$DATE.tar.gz" | cut -f1))

Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

    print_success "Backup summary created: backup_$DATE.log"
}

# Main backup function
main() {
    print_status "Starting Twenty CRM backup..."
    
    create_backup_dir
    backup_database
    backup_files
    backup_config
    cleanup_old_backups
    create_summary
    
    print_success "🎉 Backup completed successfully!"
    print_status "Backup location: $BACKUP_DIR"
    print_status "Latest backup: $DATE"
}

# Run main function
main "$@" 
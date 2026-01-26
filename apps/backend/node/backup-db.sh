#!/bin/bash

# CalCalCal Database Backup Script
# This script creates a PostgreSQL dump and manages backup rotation

set -e  # Exit on any error

echo "🗄️  Starting database backup..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="calcalcal_backup_${TIMESTAMP}.sql"
DAYS_TO_KEEP=7  # Keep backups for 7 days

# Database credentials (matches docker-compose.production.yml)
DB_USER="calcalcal"
DB_NAME="calcalcal_production"
DB_CONTAINER="calcalcal-db"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if database container is running
if ! docker ps | grep -q "$DB_CONTAINER"; then
    echo -e "${RED}❌ Error: Database container '$DB_CONTAINER' is not running${NC}"
    exit 1
fi

# Create backup using pg_dump inside the container
echo -e "${YELLOW}📦 Creating backup: $BACKUP_FILE${NC}"
docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/$BACKUP_FILE"

# Compress the backup
echo -e "${YELLOW}🗜️  Compressing backup...${NC}"
gzip "$BACKUP_DIR/$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Get file size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE ($BACKUP_SIZE)${NC}"

# Delete old backups (keep last N days)
echo -e "${YELLOW}🧹 Cleaning up old backups (keeping last $DAYS_TO_KEEP days)...${NC}"
find "$BACKUP_DIR" -name "calcalcal_backup_*.sql.gz" -type f -mtime +$DAYS_TO_KEEP -delete

# Show all backups
echo ""
echo "Available backups:"
ls -lh "$BACKUP_DIR" | grep calcalcal_backup

echo ""
echo -e "${GREEN}🎉 Backup complete!${NC}"
echo ""
echo "To restore this backup:"
echo "  1. Decompress: gunzip $BACKUP_DIR/$BACKUP_FILE"
echo "  2. Stop API: docker-compose -f docker-compose.production.yml stop api"
echo "  3. Restore: docker exec -i $DB_CONTAINER psql -U $DB_USER $DB_NAME < $BACKUP_DIR/\${BACKUP_FILE%.gz}"
echo "  4. Start API: docker-compose -f docker-compose.production.yml start api"

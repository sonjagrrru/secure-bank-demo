#!/bin/bash

# ============================================
# Banking App Database Backup Script
# ============================================

set -e

BACKUP_DIR="./backups"
BACKUP_FILE="$BACKUP_DIR/banking_db_$(date +%Y%m%d_%H%M%S).sql"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Banking App - Database Backup"
echo "================================="
echo ""
echo "Checking database..."

if ! docker ps | grep -q banking_postgres; then
    echo "PostgreSQL container is not running!"
    echo "Start the application with: ./scripts/setup.sh"
    exit 1
fi

echo "Creating backup to: $BACKUP_FILE"

docker exec banking_postgres pg_dump \
    -U banking_user \
    -d banking_db \
    --format=plain \
    > "$BACKUP_FILE"

echo "Backup created successfully!"
echo ""
echo "Location: $BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""
echo "To restore run:"
echo "  psql -U banking_user -d banking_db < $BACKUP_FILE"

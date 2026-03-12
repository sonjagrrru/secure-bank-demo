#!/bin/bash

# ============================================
# Banking App Database Backup Script
# ============================================

set -e

BACKUP_DIR="./backups"
BACKUP_FILE="$BACKUP_DIR/banking_db_$(date +%Y%m%d_%H%M%S).sql"

# Kreiraj backup direktorijum
mkdir -p "$BACKUP_DIR"

echo "Banking App - Database Backup"
echo "================================="
echo ""
echo "Proveravanja bazu podataka..."

if ! docker ps | grep -q banking_postgres; then
    echo "PostgreSQL kontejner nije pokrenut!"
    echo "Pokrenite aplikaciju sa: ./scripts/setup.sh"
    exit 1
fi

echo "Kreiram backup u: $BACKUP_FILE"

docker exec banking_postgres pg_dump \
    -U banking_user \
    -d banking_db \
    --format=plain \
    > "$BACKUP_FILE"

echo "Backup je uspešno kreiran!"
echo ""
echo "Lokacija: $BACKUP_FILE"
echo "Veličina: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""
echo "Za restore pokrenite:"
echo "  psql -U banking_user -d banking_db < $BACKUP_FILE"

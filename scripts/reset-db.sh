#!/bin/bash

# ============================================
# Banking App - Database Reset Script
# Deletes all data and seeds fresh test data
# Uses Python inside the backend container for
# API calls (avoids curl/HTTPS/rate limit issues)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Banking App - Database Reset"
echo "===================================="
echo ""
echo "WARNING: This will delete ALL existing data and replace it with fresh test data!"
echo ""
read -p "Are you sure? (y/n): " confirm

if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "[1/5] Clearing all tables..."
docker exec banking_postgres psql -U banking_user -d banking_db -c \
    "TRUNCATE audit_logs, transactions, accounts, users RESTART IDENTITY CASCADE;"
echo "      Done."

echo ""
echo "[2/5] Inserting test users..."
docker exec banking_postgres psql -U banking_user -d banking_db -c \
"INSERT INTO users (email, full_name, password_hash, role) VALUES
('admin@banking.local', 'Administrator', '\$2b\$12\$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'admin'),
('teller@banking.local', 'Teller', '\$2b\$12\$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'teller'),
('customer@banking.local', 'Customer', '\$2b\$12\$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'customer');"
echo "      Done."

echo ""
# Steps 3-4: Create accounts and transactions via API using Python inside the backend container
docker exec -i banking_backend python < "$SCRIPT_DIR/reset-db-seed.py"
if [ $? -ne 0 ]; then
    echo "ERROR: Seed script failed."
    exit 1
fi

echo ""
echo "[5/5] Verifying data..."
echo ""
docker exec banking_postgres psql -U banking_user -d banking_db -c \
    "SELECT 'users' AS table_name, COUNT(*) FROM users UNION ALL SELECT 'accounts', COUNT(*) FROM accounts UNION ALL SELECT 'transactions', COUNT(*) FROM transactions UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"

echo ""
echo "===================================="
echo "Database reset complete!"
echo ""
echo "Test users (password: admin123):"
echo "  - admin@banking.local    (admin)"
echo "  - teller@banking.local   (teller)"
echo "  - customer@banking.local (customer)"
echo ""
echo "Each user has 2 accounts (checking + savings)."
echo "===================================="

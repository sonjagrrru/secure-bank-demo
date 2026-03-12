@echo off
chcp 65001 >nul
REM ============================================
REM Banking App - Database Reset Script
REM Deletes all data and seeds fresh test data
REM Uses Python inside the backend container for
REM API calls (avoids shell quoting issues)
REM ============================================

setlocal enabledelayedexpansion

echo Banking App - Database Reset
echo ====================================
echo.
echo WARNING: This will delete ALL existing data and replace it with fresh test data!
echo.
set /p confirm="Are you sure? (y/n): "
if /i not "%confirm%"=="y" (
    echo Cancelled.
    exit /b 0
)

echo.
echo [1/5] Clearing all tables...
docker exec banking_postgres psql -U banking_user -d banking_db -c "TRUNCATE audit_logs, transactions, accounts, users RESTART IDENTITY CASCADE;"
if errorlevel 1 (
    echo ERROR: Could not clear database. Is the postgres container running?
    echo Run scripts\setup.bat first.
    exit /b 1
)
echo       Done.

echo.
echo [2/5] Inserting test users...
docker exec banking_postgres psql -U banking_user -d banking_db -c ^
"INSERT INTO users (email, full_name, password_hash, role) VALUES ^
('admin@banking.local', 'Administrator', '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'admin'), ^
('teller@banking.local', 'Teller', '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'teller'), ^
('customer@banking.local', 'Customer', '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e', 'customer');"
echo       Done.

echo.
REM Steps 3-4: Create accounts and transactions via API using Python inside the backend container
docker exec -i banking_backend python < "%~dp0reset-db-seed.py"
if errorlevel 1 (
    echo ERROR: Seed script failed.
    exit /b 1
)

echo.
echo [5/5] Verifying data...
echo.
docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT 'users' AS table_name, COUNT(*) FROM users UNION ALL SELECT 'accounts', COUNT(*) FROM accounts UNION ALL SELECT 'transactions', COUNT(*) FROM transactions UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"

echo.
echo ====================================
echo Database reset complete!
echo.
echo Test users (password: admin123):
echo   - admin@banking.local    (admin)
echo   - teller@banking.local   (teller)
echo   - customer@banking.local (customer)
echo.
echo Each user has 2 accounts (checking + savings).
echo ====================================

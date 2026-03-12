@echo off
chcp 65001 >nul
echo ============================================
echo   PostgreSQL - Database Contents Overview
echo ============================================
echo.
echo Use the following commands in PowerShell:
echo.
echo --- TABLES IN DATABASE ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "\dt"
echo.
echo --- ALL USERS ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT id, email, full_name, role, is_active, created_at FROM users;"
echo.
echo --- ALL ACCOUNTS ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT id, user_id, account_number, account_type, is_active, created_at FROM accounts;"
echo.
echo --- ALL TRANSACTIONS ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT * FROM transactions;"
echo.
echo --- AUDIT LOG (last 20) ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT * FROM audit_logs ORDER BY id DESC LIMIT 20;"
echo.
echo --- TABLE STRUCTURE (example: users) ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "\d users"
echo.
echo --- ROW COUNT PER TABLE ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT 'users' AS table_name, COUNT(*) FROM users UNION ALL SELECT 'accounts', COUNT(*) FROM accounts UNION ALL SELECT 'transactions', COUNT(*) FROM transactions UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"
echo.

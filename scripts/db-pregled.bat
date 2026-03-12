@echo off
chcp 65001 >nul
echo ============================================
echo   PostgreSQL - Pregled sadrzaja baze
echo ============================================
echo.
echo Koristite sledece komande u PowerShell-u:
echo.
echo --- TABELE U BAZI ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "\dt"
echo.
echo --- SVI KORISNICI ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT id, email, full_name, role, is_active, created_at FROM users;"
echo.
echo --- SVI RACUNI ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT id, user_id, account_number, account_type, is_active, created_at FROM accounts;"
echo.
echo --- SVE TRANSAKCIJE ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT * FROM transactions;"
echo.
echo --- AUDIT LOG (poslednjih 20) ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT * FROM audit_logs ORDER BY id DESC LIMIT 20;"
echo.
echo --- STRUKTURA TABELE (primer: users) ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "\d users"
echo.
echo --- BROJ REDOVA PO TABELI ---
echo docker exec banking_postgres psql -U banking_user -d banking_db -c "SELECT 'users' AS tabela, COUNT(*) FROM users UNION ALL SELECT 'accounts', COUNT(*) FROM accounts UNION ALL SELECT 'transactions', COUNT(*) FROM transactions UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"
echo.

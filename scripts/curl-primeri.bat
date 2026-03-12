@echo off
chcp 65001 >nul 2>&1
echo ============================================================
echo   CURL COMMANDS FOR MANUAL TESTING
echo   Copy and run in PowerShell one by one
echo ============================================================
echo.
echo --- STEP 0: Ignore SSL (must run first) ---
echo.
echo [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
echo.
echo --- STEP 1: Login (admin) ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"admin@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo $r
echo $token = "PASTE_TOKEN_HERE"
echo.

echo.
echo --- STEP 1.2: View accounts 2 ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer $token"}
echo
echo [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo $token=""
echo curl.exe -k -H "Authorization: Bearer $token" https://localhost/api/accounts
echo.
echo Wait 1 minute for token to expire...
echo.
echo curl.exe -k -H "Authorization: Bearer $token" https://localhost/api/accounts

echo --- STEP 2: View accounts ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer $token"}
echo.
echo --- STEP 3: View users (admin) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/admin/users" -Headers @{Authorization="Bearer $token"}
echo.
echo --- STEP 4: Transfer money ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/transactions/transfer" -Method POST -Headers @{Authorization="Bearer $token"} -Body '{"from_account_id":7,"to_account_id":8,"amount":100,"description":"Test"}' -ContentType "application/json"
echo.
echo --- STEP 5: Transactions for account ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/transactions/7" -Headers @{Authorization="Bearer $token"}
echo.
echo --- STEP 6: Audit log (admin) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/admin/audit-log" -Headers @{Authorization="Bearer $token"}
echo.
echo --- STEP 7: Without token (should return error) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts"
echo.
echo --- STEP 8: With fake token (should return error) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer laznitorken123"}
echo.
echo --- Login as teller ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"teller@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo.
echo --- Login as customer ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"customer@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo.
echo ============================================================
pause

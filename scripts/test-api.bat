@echo off
REM ============================================
REM Banking App API Test Script for Windows
REM ============================================

setlocal enabledelayedexpansion

set API_URL=http://localhost

echo Banking App - API Test Script for Windows
echo ==========================================
echo.

REM Check if API is available
echo Proveravam da li je API dostupan...
curl -s %API_URL%/api/health >nul 2>&1
if errorlevel 1 (
    echo API NIJE DOSTUPAN
    echo Pokrenite aplikaciju sa: scripts\setup.bat
    exit /b 1
)
echo API DOSTUPAN
echo.

REM Test 1: Health Check
echo [TEST 1] Health Check
curl -s -X GET %API_URL%/api/health | jq .
echo.
echo.

REM Test 2: Register
echo [TEST 2] Register New User
for /f "tokens=1" %%A in ('powershell Get-Random') do set RAND=%%A
curl -s -X POST %API_URL%/api/auth/register ^
  -H "Content-Type: application/json" ^
  -d "{\"email\": \"test_%RAND%@banking.local\", \"full_name\": \"Test User\", \"password\": \"testpass123\"}" | jq .
echo.
echo.

REM Test 3: Login
echo [TEST 3] Login
for /f %%A in ('curl -s -X POST %API_URL%/api/auth/login -H "Content-Type: application/json" -d "{\"email\": \"admin@banking.local\", \"password\": \"admin123\"}" ^| jq -r ".token"') do set TOKEN=%%A

if "!TOKEN!"=="" (
    echo Login nije uspio - nema tokena
    exit /b 1
)

curl -s -X POST %API_URL%/api/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\": \"admin@banking.local\", \"password\": \"admin123\"}" | jq .
echo.
echo.

REM Test 4: Health Check sa Tokenom
echo [TEST 4] Health Check sa Autentifikacijom
curl -s -X GET %API_URL%/api/health ^
  -H "Authorization: Bearer !TOKEN!" | jq .
echo.
echo.

REM Test 5: Create Account
echo [TEST 5] Create Account
for /f %%A in ('curl -s -X POST %API_URL%/api/accounts -H "Content-Type: application/json" -H "Authorization: Bearer !TOKEN!" -d "{\"account_type\": \"checking\", \"initial_balance\": 5000}" ^| jq -r ".account_id"') do set ACCOUNT_ID=%%A

curl -s -X POST %API_URL%/api/accounts ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer !TOKEN!" ^
  -d "{\"account_type\": \"checking\", \"initial_balance\": 5000}" | jq .
echo.
echo.

if "!ACCOUNT_ID!"=="" (
    echo Nije moguće testirati dalje bez računa
    exit /b 0
)

REM Test 6: Get Account
echo [TEST 6] Get Account Details
curl -s -X GET %API_URL%/api/accounts/!ACCOUNT_ID! ^
  -H "Authorization: Bearer !TOKEN!" | jq .
echo.
echo.

REM Test 7: Create Second Account
echo [TEST 7] Create Second Account for Transfer
for /f %%A in ('curl -s -X POST %API_URL%/api/accounts -H "Content-Type: application/json" -H "Authorization: Bearer !TOKEN!" -d "{\"account_type\": \"savings\", \"initial_balance\": 1000}" ^| jq -r ".account_id"') do set SECOND_ACCOUNT_ID=%%A

curl -s -X POST %API_URL%/api/accounts ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer !TOKEN!" ^
  -d "{\"account_type\": \"savings\", \"initial_balance\": 1000}" | jq .
echo.
echo.

if "!SECOND_ACCOUNT_ID!"=="" (
    echo Nije moguce testirati transfere bez drugog racuna
    exit /b 0
)

REM Test 8: Transfer Money
echo [TEST 8] Transfer Money Between Accounts
curl -s -X POST %API_URL%/api/transactions/transfer ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer !TOKEN!" ^
  -d "{\"from_account_id\": !ACCOUNT_ID!, \"to_account_id\": !SECOND_ACCOUNT_ID!, \"amount\": 100, \"description\": \"Test transfer\"}" | jq .
echo.
echo.

REM Test 9: Get Audit Log
echo [TEST 9] Get Audit Log
curl -s -X GET %API_URL%/api/admin/audit-log ^
  -H "Authorization: Bearer !TOKEN!" | jq ".audit_logs | .[0:3]"
echo.
echo.

echo Testiranje je završeno!

@echo off
chcp 65001 >nul 2>&1
echo ============================================================
echo   CURL KOMANDE ZA RUCNO TESTIRANJE
echo   Kopiraj i pokreni u PowerShell-u jednu po jednu
echo ============================================================
echo.
echo --- KORAK 0: Ignoriši SSL (obavezno prvo pokrenuti) ---
echo.
echo [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
echo.
echo --- KORAK 1: Prijava (admin) ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"admin@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo $r
echo $token = "ZALEPI_TOKEN_OVDE"
echo.

echo.
echo --- KORAK 1.2: Pregled racuna 2 ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer $token"}
echo
echo [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo $token=""
echo curl.exe -k -H "Authorization: Bearer $token" https://localhost/api/accounts
echo.
echo Cekaj 1 minut da token istekne...
echo.
echo curl.exe -k -H "Authorization: Bearer $token" https://localhost/api/accounts

echo --- KORAK 2: Pregled racuna ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer $token"}
echo.
echo --- KORAK 3: Pregled korisnika (admin) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/admin/users" -Headers @{Authorization="Bearer $token"}
echo.
echo --- KORAK 4: Transfer novca ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/transactions/transfer" -Method POST -Headers @{Authorization="Bearer $token"} -Body '{"from_account_id":7,"to_account_id":8,"amount":100,"description":"Test"}' -ContentType "application/json"
echo.
echo --- KORAK 5: Transakcije za racun ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/transactions/7" -Headers @{Authorization="Bearer $token"}
echo.
echo --- KORAK 6: Audit log (admin) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/admin/audit-log" -Headers @{Authorization="Bearer $token"}
echo.
echo --- KORAK 7: Bez tokena (treba da vrati gresku) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts"
echo.
echo --- KORAK 8: Sa laznim tokenom (treba da vrati gresku) ---
echo.
echo Invoke-RestMethod -Uri "https://localhost/api/accounts" -Headers @{Authorization="Bearer laznitorken123"}
echo.
echo --- Prijava kao teller ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"teller@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo.
echo --- Prijava kao customer ---
echo.
echo $r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST -Body '{"email":"customer@banking.local","password":"admin123"}' -ContentType "application/json"
echo $token = $r.token
echo.
echo ============================================================
pause

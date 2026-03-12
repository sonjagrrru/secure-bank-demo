@echo off
chcp 65001 >nul
echo ============================================
echo   Test Rate Limiting
echo ============================================
echo.
echo Login endpoint je ogranicen na 5 zahteva/minut u Nginx-u.
echo Ova komanda salje 10 brzih zahteva - posle 5-6 dobijas HTTP 429 (Too Many Requests).
echo.
echo --- TEST LOGIN RATE LIMIT (5/min) ---
echo for ($i = 1; $i -le 10; $i++) { $r = curl.exe -k -s -o NUL -w "%%{http_code}" -X POST https://localhost/api/auth/login -H "Content-Type: application/json" -d '{\"email\":\"test@test.com\",\"password\":\"wrong\"}'; Write-Host "Zahtev $i : HTTP $r" }
echo.
echo --- TEST API RATE LIMIT (10/s) ---
echo for ($i = 1; $i -le 20; $i++) { $r = curl.exe -k -s -o NUL -w "%%{http_code}" https://localhost/api/health; Write-Host "Zahtev $i : HTTP $r" }
echo.
echo ============================================
echo   Ocekivani rezultat:
echo   - Prvih 5-6 zahteva: HTTP 401 (pogresna lozinka)
echo   - Posle toga: HTTP 429 (rate limit)
echo ============================================

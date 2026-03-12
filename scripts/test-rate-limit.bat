@echo off
chcp 65001 >nul
echo ============================================
echo   Test Rate Limiting
echo ============================================
echo.
echo Login endpoint is limited to 5 requests/minute in Nginx.
echo This command sends 10 fast requests - after 5-6 you get HTTP 429 (Too Many Requests).
echo.
echo --- TEST LOGIN RATE LIMIT (5/min) ---
echo for ($i = 1; $i -le 10; $i++) { $r = curl.exe -k -s -o NUL -w "%%{http_code}" -X POST https://localhost/api/auth/login -H "Content-Type: application/json" -d '{\"email\":\"test@test.com\",\"password\":\"wrong\"}'; Write-Host "Request $i : HTTP $r" }
echo.
echo --- TEST API RATE LIMIT (10/s) ---
echo for ($i = 1; $i -le 20; $i++) { $r = curl.exe -k -s -o NUL -w "%%{http_code}" https://localhost/api/health; Write-Host "Request $i : HTTP $r" }
echo.
echo ============================================
echo   Expected result:
echo   - First 5-6 requests: HTTP 401 (wrong password)
echo   - After that: HTTP 429 (rate limit)
echo ============================================

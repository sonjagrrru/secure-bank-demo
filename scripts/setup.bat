@echo off
REM ============================================
REM Banking App Setup Script for Windows
REM ============================================

setlocal enabledelayedexpansion

echo Banking App - Setup Script for Windows
echo ==========================================
echo.

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo Docker nije instaliran. Molimo instalirajte Docker Desktop.
    exit /b 1
)

REM Check Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo Docker Compose nije instaliran.
    exit /b 1
)

REM Create .env file if not exists
if not exist .env (
    echo Kreiram .env fajl...
    copy .env.example .env
    echo .env fajl je kreiran - OBAVEZNO ga uredite sa svojim vrednostima!
)

REM Create SSL certificates if not exist
if not exist docker\certs\banking.crt (
    if not exist docker\certs (
        mkdir docker\certs
    )
    echo Kreiram SSL sertifikate...
    REM Note: Self-signed cert generation na Windows zahteva OpenSSL
    echo Za SSL sertifikate, pokrenite:
    echo    openssl req -x509 -newkey rsa:4096 -nodes -out docker\certs\banking.crt -keyout docker\certs\banking.key -days 365
)

REM Start Docker Compose
echo.
echo Pokrecem Docker kontejnere...
docker-compose -f docker/docker-compose.yml up -d

echo.
echo Cekam da se servisi pokrenu...
timeout /t 10 /nobreak

echo.
echo Provera zdravlja servisa...

REM Check PostgreSQL
echo   PostgreSQL:
docker exec banking_postgres pg_isready -U banking_user -d banking_db >nul 2>&1
if errorlevel 1 (
    echo     Nije dostupan
) else (
    echo     Spreman
)

REM Check Nginx (reverse proxy)
echo   Nginx (reverse proxy):
curl -s http://localhost/health >nul 2>&1
if errorlevel 1 (
    echo     Pokretanje se jos uvek desava...
) else (
    echo     Spreman
)

REM Check Backend API (kroz Nginx)
echo   Backend API (kroz Nginx):
curl -s http://localhost/api/health >nul 2>&1
if errorlevel 1 (
    echo     Pokretanje se jos uvek desava...
) else (
    echo     Spreman
)

echo.
echo Setup je zavrsen!
echo.
echo Dostupne aplikacije (sve kroz Nginx reverse proxy):
echo   - Frontend:     http://localhost  (ili https://localhost)
echo   - Backend API:  http://localhost/api
echo.
echo Interni servisi (dostupni samo unutar Docker mreze):
echo   - Backend:      banking_backend:5000
echo   - PostgreSQL:   banking_postgres:5432
echo.
echo Test korisnici:
echo   - admin@banking.local (admin)
echo   - teller@banking.local (teller)
echo   - customer@banking.local (customer)
echo   - Lozinka: admin123
echo.
echo Za vise informacija vidite README.md
echo.
echo Za zaustavljanje pokrenite:
echo    docker-compose -f docker/docker-compose.yml down

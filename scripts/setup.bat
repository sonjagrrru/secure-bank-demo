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
    echo Docker is not installed. Please install Docker Desktop.
    exit /b 1
)

REM Check Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo Docker Compose is not installed.
    exit /b 1
)

REM Create .env file if not exists
if not exist .env (
    echo Creating .env file...
    copy .env.example .env
    echo .env file created - MAKE SURE to edit it with your own values!
)

REM Create SSL certificates if not exist
if not exist docker\certs\banking.crt (
    if not exist docker\certs (
        mkdir docker\certs
    )
    echo Creating SSL certificates...
    REM Note: Self-signed cert generation on Windows requires OpenSSL
    echo For SSL certificates, run:
    echo    openssl req -x509 -newkey rsa:4096 -nodes -out docker\certs\banking.crt -keyout docker\certs\banking.key -days 365
)

REM Start Docker Compose
echo.
echo Starting Docker containers...
docker-compose -f docker/docker-compose.yml up -d

echo.
echo Waiting for services to start...
timeout /t 10 /nobreak

echo.
echo Checking service health...

REM Check PostgreSQL
echo   PostgreSQL:
docker exec banking_postgres pg_isready -U banking_user -d banking_db >nul 2>&1
if errorlevel 1 (
    echo     Not available
) else (
    echo     Ready
)

REM Check Nginx (reverse proxy)
echo   Nginx (reverse proxy):
curl -s http://localhost/health >nul 2>&1
if errorlevel 1 (
    echo     Still starting up...
) else (
    echo     Ready
)

REM Check Backend API (through Nginx)
echo   Backend API (through Nginx):
curl -s http://localhost/api/health >nul 2>&1
if errorlevel 1 (
    echo     Still starting up...
) else (
    echo     Ready
)

echo.
echo Setup is complete!
echo.
echo Available applications (all through Nginx reverse proxy):
echo   - Frontend:     http://localhost  (ili https://localhost)
echo   - Backend API:  http://localhost/api
echo.
echo Internal services (only accessible within Docker network):
echo   - Backend:      banking_backend:5000
echo   - PostgreSQL:   banking_postgres:5432
echo.
echo Test users:
echo   - admin@banking.local (admin)
echo   - teller@banking.local (teller)
echo   - customer@banking.local (customer)
echo   - Password: admin123
echo.
echo For more information see README.md
echo.
echo To stop run:
echo    docker-compose -f docker/docker-compose.yml down

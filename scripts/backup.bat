@echo off
REM ============================================
REM Banking App Database Backup Script for Windows
REM ============================================

setlocal enabledelayedexpansion

set BACKUP_DIR=backups
if not exist %BACKUP_DIR% (
    mkdir %BACKUP_DIR%
)

REM Create timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set BACKUP_FILE=%BACKUP_DIR%\banking_db_%mydate%_%mytime%.sql

echo Banking App - Database Backup
echo =================================
echo.
echo Proveravanja bazu podataka...

REM Check if PostgreSQL container is running
docker ps | find "banking_postgres" >nul
if errorlevel 1 (
    echo PostgreSQL kontejner nije pokrenut!
    echo Pokrenite aplikaciju sa: scripts\setup.bat
    exit /b 1
)

echo Kreiram backup u: %BACKUP_FILE%

docker exec banking_postgres pg_dump -U banking_user -d banking_db --format=plain > %BACKUP_FILE%

if errorlevel 1 (
    echo Backup nije uspeo!
    exit /b 1
)

echo Backup je uspesno kreiran!
echo.
echo Lokacija: %BACKUP_FILE%
echo.
echo Za restore pokrenite:
echo   psql -U banking_user -d banking_db ^< %BACKUP_FILE%

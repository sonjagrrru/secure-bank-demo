@echo off
REM ============================================
REM Banking App Teardown Script for Windows
REM ============================================

echo Banking App - Teardown Script for Windows
echo ============================================

REM Check Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo Docker Compose nije instaliran.
    exit /b 1
)

echo Zaustavljam kontejnere...
docker-compose -f docker/docker-compose.yml down

echo.
set /p response="Želite li da obrišete podatke iz baze? (y/n): "

if /i "%response%"=="y" (
    echo Brisem volume...
    docker-compose -f docker/docker-compose.yml down -v
    echo Podaci su obrisani
) else (
    echo Podaci su sacuvani
)

echo.
echo Teardown je zavrsen!

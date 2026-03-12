@echo off
REM ============================================
REM Banking App Teardown Script for Windows
REM ============================================

echo Banking App - Teardown Script for Windows
echo ============================================

REM Check Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo Docker Compose is not installed.
    exit /b 1
)

echo Stopping containers...
docker-compose -f docker/docker-compose.yml down

echo.
set /p response="Do you want to delete database data? (y/n): "

if /i "%response%"=="y" (
    echo Deleting volumes...
    docker-compose -f docker/docker-compose.yml down -v
    echo Data has been deleted
) else (
    echo Data has been preserved
)

echo.
echo Teardown is complete!

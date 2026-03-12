@echo off
REM ============================================
REM Banking App Logs Script for Windows
REM ============================================

echo Banking App - Logs
echo ====================
echo.
echo Showing logs for all services...
echo Press CTRL+C to exit
echo.

docker-compose -f docker/docker-compose.yml logs -f

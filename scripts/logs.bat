@echo off
REM ============================================
REM Banking App Logs Script for Windows
REM ============================================

echo Banking App - Logs
echo ====================
echo.
echo Prikazujem logove sa svim servisima...
echo Za izlaz pritisnite CTRL+C
echo.

docker-compose -f docker/docker-compose.yml logs -f

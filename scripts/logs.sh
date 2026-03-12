#!/bin/bash

# ============================================
# Banking App Logs Script
# ============================================

set -e

echo "Banking App - Logs"
echo "===================="
echo ""
echo "Showing logs for all services..."
echo "Press CTRL+C to exit"
echo ""

docker-compose -f docker/docker-compose.yml logs -f

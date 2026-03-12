#!/bin/bash

# ============================================
# Banking App Teardown Script
# ============================================

set -e

echo "Banking App - Teardown Script"
echo "=================================="

# Check Docker
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed."
    exit 1
fi

echo "Stopping containers..."
docker-compose -f docker/docker-compose.yml down

echo ""
echo "Do you want to delete database data? (y/n)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Deleting volumes..."
    docker-compose -f docker/docker-compose.yml down -v
    echo "Data has been deleted"
else
    echo "Data has been preserved"
fi

echo ""
echo "Teardown is complete!"

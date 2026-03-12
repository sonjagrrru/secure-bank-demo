#!/bin/bash

# ============================================
# Banking App Teardown Script
# ============================================

set -e

echo "Banking App - Teardown Script"
echo "=================================="

# Provera Docker-a
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose nije instaliran."
    exit 1
fi

echo "Zaustavljam kontejnere..."
docker-compose -f docker/docker-compose.yml down

echo ""
echo "Želite li da obrišete podatke iz baze? (y/n)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Brišem volume..."
    docker-compose -f docker/docker-compose.yml down -v
    echo "Podaci su obrisani"
else
    echo "Podaci su sačuvani"
fi

echo ""
echo "Teardown je završen!"

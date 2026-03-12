#!/bin/bash

# ============================================
# Banking App Setup Script
# ============================================

set -e

echo "Banking App - Setup Script"
echo "=============================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo ".env file created - MAKE SURE to edit it with your own values!"
fi

# Check if required keys are set
if grep -q "change-this-in-production" .env; then
    echo "Warning: Production passwords will not be forwarded!"
    echo "Please edit the .env file with secure keys:"
    echo "   - SECRET_KEY"
    echo "   - ENCRYPTION_KEY"
    echo ""
    echo "To generate ENCRYPTION_KEY use:"
    echo "   python3 -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
fi

# Create SSL certificates if they don't exist
if [ ! -f docker/certs/banking.crt ] || [ ! -f docker/certs/banking.key ]; then
    echo "Creating SSL certificates..."
    mkdir -p docker/certs
    openssl req -x509 -newkey rsa:4096 -nodes \
        -out docker/certs/banking.crt \
        -keyout docker/certs/banking.key \
        -days 365 \
        -subj "/C=RS/ST=Serbia/L=Belgrade/O=Banking/CN=localhost"
    echo "SSL certificates created"
fi

# Start Docker Compose
echo ""
echo "Starting Docker containers..."
docker-compose -f docker/docker-compose.yml up -d

echo ""
echo "Waiting for services to start..."
sleep 10

# Check service health
echo ""
echo "Checking service health..."

# Check PostgreSQL
echo -n "  PostgreSQL: "
if docker exec banking_postgres pg_isready -U banking_user -d banking_db > /dev/null 2>&1; then
    echo "Ready"
else
    echo "Not available"
fi

# Check Nginx (reverse proxy)
echo -n "  Nginx (reverse proxy): "
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo "Ready"
else
    echo "Still starting up..."
fi

# Check Backend API (through Nginx)
echo -n "  Backend API (through Nginx): "
if curl -s http://localhost/api/health > /dev/null 2>&1; then
    echo "Ready"
else
    echo "Still starting up..."
fi

echo ""
echo "Setup is complete!"
echo ""
echo "Available applications (all through Nginx reverse proxy):"
echo "  - Frontend:     http://localhost  (or https://localhost)"
echo "  - Backend API:  http://localhost/api"
echo ""
echo "Internal services (only accessible within Docker network):"
echo "  - Backend:      banking_backend:5000"
echo "  - PostgreSQL:   banking_postgres:5432"
echo ""
echo "Test users:"
echo "  - admin@banking.local (admin)"
echo "  - teller@banking.local (teller)"
echo "  - customer@banking.local (customer)"
echo "  - Password: admin123"
echo ""
echo "For more information see README.md"
echo ""
echo "To stop run:"
echo "   docker-compose -f docker/docker-compose.yml down"

#!/bin/bash

# ============================================
# Banking App Setup Script
# ============================================

set -e

echo "Banking App - Setup Script"
echo "=============================="

# Provera Docker-a
if ! command -v docker &> /dev/null; then
    echo "Docker nije instaliran. Molimo instalirajte Docker prvo."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose nije instaliran. Molimo instalirajte Docker Compose prvo."
    exit 1
fi

# Kreiraj .env fajl ako ne postoji
if [ ! -f .env ]; then
    echo "Kreiram .env fajl..."
    cp .env.example .env
    echo ".env fajl je kreiran - OBAVEZNO ga uredite sa svojim vrednostima!"
fi

# Provera da li su potrebni ključevi postavljeni
if grep -q "change-this-in-production" .env; then
    echo "Upozorenje: Nece biti prosljedjene produkcijske lozinke!"
    echo "Molimo uredite .env fajl sa sigurnim kljucevima:"
    echo "   - SECRET_KEY"
    echo "   - ENCRYPTION_KEY"
    echo ""
    echo "Za generisanje ENCRYPTION_KEY koristite:"
    echo "   python3 -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
fi

# Kreiraj SSL sertifikate ako ne postoje
if [ ! -f docker/certs/banking.crt ] || [ ! -f docker/certs/banking.key ]; then
    echo "Kreiram SSL sertifikate..."
    mkdir -p docker/certs
    openssl req -x509 -newkey rsa:4096 -nodes \
        -out docker/certs/banking.crt \
        -keyout docker/certs/banking.key \
        -days 365 \
        -subj "/C=RS/ST=Serbia/L=Belgrade/O=Banking/CN=localhost"
    echo "SSL sertifikati su kreirani"
fi

# Pokreni Docker Compose
echo ""
echo "Pokrecem Docker kontejnere..."
docker-compose -f docker/docker-compose.yml up -d

echo ""
echo "Cekam da se servisi pokrenu..."
sleep 10

# Proveri zdravlje servisa
echo ""
echo "Provera zdravlja servisa..."

# Provjeri PostgreSQL
echo -n "  PostgreSQL: "
if docker exec banking_postgres pg_isready -U banking_user -d banking_db > /dev/null 2>&1; then
    echo "Spreman"
else
    echo "Nije dostupan"
fi

# Provjeri Nginx (reverse proxy)
echo -n "  Nginx (reverse proxy): "
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo "Spreman"
else
    echo "Pokretanje se još uvek dešava..."
fi

# Provjeri Backend API (kroz Nginx)
echo -n "  Backend API (kroz Nginx): "
if curl -s http://localhost/api/health > /dev/null 2>&1; then
    echo "Spreman"
else
    echo "Pokretanje se još uvek dešava..."
fi

echo ""
echo "Setup je zavrsen!"
echo ""
echo "Dostupne aplikacije (sve kroz Nginx reverse proxy):"
echo "  - Frontend:     http://localhost  (ili https://localhost)"
echo "  - Backend API:  http://localhost/api"
echo ""
echo "Interni servisi (dostupni samo unutar Docker mreze):"
echo "  - Backend:      banking_backend:5000"
echo "  - PostgreSQL:   banking_postgres:5432"
echo ""
echo "Test korisnike:"
echo "  - admin@banking.local (admin)"
echo "  - teller@banking.local (teller)"
echo "  - customer@banking.local (customer)"
echo "  - Lozinka: admin123"
echo ""
echo "Za više informacija vidite README.md"
echo ""
echo "Za zaustavljanje pokrenite:"
echo "   docker-compose -f docker/docker-compose.yml down"

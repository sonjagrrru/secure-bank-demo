# Secure Bank Demo

A demo application for **secure banking operations** that demonstrates security best practices in web applications. Designed as an educational example for data protection, authentication, authorization, and encryption in a production-like environment.

## What Does This Application Do?

Simulates a complete banking application with:

- **User accounts** with three access levels (customer, teller, admin)
- **Bank accounts** with encrypted balances (AES-256 Fernet encryption at rest)
- **Money transfers** between accounts with a full audit trail
- **Admin panel** for user management and audit log review

## Security Features

| Feature | Implementation |
|---------|---------------|
| Authentication | JWT tokens with automatic refresh |
| Authorization | RBAC — customer, teller, admin roles |
| Passwords | bcrypt hashing with salt |
| Data encryption | AES-256 (Fernet) for balances and transaction amounts |
| Rate limiting | Nginx: 10 req/s for API, 5 req/min for login |
| HTTPS/TLS | Self-signed cert for dev, TLS 1.2/1.3 |
| Security headers | HSTS, X-Frame-Options, CSP, X-Content-Type-Options |
| Network isolation | Private Docker network, only Nginx exposed publicly |
| Containers | Non-root users, no-new-privileges, cap_drop ALL |
| Audit logging | Every action logged with IP address and timestamp |

## Architecture

```
                    ┌──────────────┐
   Port 80/443 ──> │    Nginx     │  (reverse proxy, SSL, rate limit)
                    └──────┬───────┘
                           │ private network (10.0.9.0/24)
                ┌──────────┴──────────┐
                │                     │
         ┌──────┴──────┐      ┌───────┴──────┐
         │   Frontend  │      │   Backend    │
         │  React:3000 │      │ Flask:5000   │
         └─────────────┘      └──────┬───────┘
                                     │
                              ┌──────┴───────┐
                              │  PostgreSQL  │
                              │    :5432     │
                              └──────────────┘
```

All services except Nginx are **private** — accessible only within the Docker network.

## Quick Start

### Running

```powershell
# Windows
scripts\setup.bat

# Linux / macOS
./scripts/setup.sh
```

Or manually:

```powershell
docker compose -f docker/docker-compose.yml up -d --build
```

### Access

| What | URL |
|------|-----|
| Frontend | http://localhost or https://localhost |
| API | http://localhost/api/health |

### Test Users

| Email | Password | Role |
|-------|----------|------|
| admin@banking.local | admin123 | admin |
| teller@banking.local | admin123 | teller |
| customer@banking.local | admin123 | customer |

### Stopping

```powershell
scripts\teardown.bat
```

## Rebuilding After Changes

After modifying any source code (frontend, backend, Docker configs, etc.), rebuild and restart the affected containers:

```powershell
# Rebuild everything
docker compose -f docker/docker-compose.yml up -d --build

# Or rebuild only what you changed:
docker compose -f docker/docker-compose.yml up -d --build backend    # Python/Flask changes
docker compose -f docker/docker-compose.yml up -d --build frontend   # React changes
docker compose -f docker/docker-compose.yml up -d --build nginx      # Nginx config changes
docker compose -f docker/docker-compose.yml up -d --build postgres   # DB schema / init-db.sql changes
```

**When to rebuild Nginx:**
- Changed `docker/nginx.conf` (rate limits, proxy rules, security headers, server blocks)
- Changed SSL certificates in `docker/certs/`
- Changed `docker/Dockerfile.nginx`

Nginx does **not** need rebuilding for backend, frontend, or database code changes — it only forwards traffic.

> **Note:** Changes to `init-db.sql` only take effect on a fresh database. If the database already exists, use the reset script below or drop the volume first with `docker compose -f docker/docker-compose.yml down -v`.

## Database Reset

To wipe all data and re-seed the database with fresh test data:

```powershell
# Windows
scripts\reset-db.bat

# Linux / macOS
./scripts/reset-db.sh
```

The script:
1. Truncates all tables (users, accounts, transactions, audit_logs)
2. Inserts 3 test users (admin, teller, customer — password: `admin123`)
3. Creates 2 accounts per user (checking + savings) via API (balances are Fernet-encrypted)
4. Creates sample transactions (transfers between accounts)
5. Verifies final row counts

> Account balances are encrypted at rest (AES-256 Fernet), so accounts and transactions **must** be created through the API — not via direct SQL inserts.

## Security Testing

### 1. Access Without Token (should return 401)

```powershell
# Attempt to access protected endpoints without authentication
curl -k https://localhost/api/accounts
curl -k https://localhost/api/admin/users
curl -k -X POST https://localhost/api/transactions/transfer `
  -H "Content-Type: application/json" `
  -d '{"from_account_id":1,"to_account_id":2,"amount":500}'
```

### 2. Fake Token (should return 401)

```powershell
curl -k https://localhost/api/accounts -H "Authorization: Bearer faketoken123"
curl -k https://localhost/api/accounts -H "Authorization: Bearer "
curl -k https://localhost/api/accounts -H "Authorization: sometoken"
```

### 3. Login and Obtain Tokens

```powershell
# Admin login
$r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST `
  -Body '{"email":"admin@banking.local","password":"admin123"}' `
  -ContentType "application/json"
$tokenAdmin = $r.token

# Customer login
$r = Invoke-RestMethod -Uri "https://localhost/api/auth/login" -Method POST `
  -Body '{"email":"customer@banking.local","password":"admin123"}' `
  -ContentType "application/json"
$tokenCustomer = $r.token
```

### 4. RBAC — Customer Cannot Access Admin Endpoints (should return 403)

```powershell
curl -k https://localhost/api/admin/users -H "Authorization: Bearer $tokenCustomer"
curl -k https://localhost/api/admin/audit-log -H "Authorization: Bearer $tokenCustomer"
```

### 5. Customer Cannot View Other Users' Accounts (should return 403)

```powershell
# Customer attempts to view admin's account
curl -k https://localhost/api/accounts/7 -H "Authorization: Bearer $tokenCustomer"
```

### 6. Rate Limiting Test (after 5 requests → HTTP 429)

```powershell
# Login endpoint: limited to 5/min
for ($i = 1; $i -le 10; $i++) {
    $r = curl.exe -k -s -o NUL -w "%{http_code}" -X POST https://localhost/api/auth/login `
      -H "Content-Type: application/json" `
      -d '{"email":"test@test.com","password":"wrong"}'
    Write-Host "Request $i : HTTP $r"
}
```

### 7. Invalid Credentials (should return 401)

```powershell
curl -k -X POST https://localhost/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"admin@banking.local","password":"wrong_password"}'
```

### 8. Automated Security Tests

```powershell
# Full test suite (21 tests)
.\scripts\test-security.ps1
```

The script tests:
- Unauthenticated access (4 tests)
- Fake/invalid tokens (3 tests)
- Customer → admin access (2 tests)
- Teller → admin access (2 tests)
- Cross-account access (2 tests)
- Cross-account transfers (2 tests)
- Invalid credentials (2 tests)
- Valid access — control group (5 tests)

## Other Commands

```powershell
scripts\logs.bat              # Follow logs from all containers
scripts\test-api.bat          # Functional API tests
scripts\backup.bat            # Database backup
scripts\db-pregled.bat        # SQL commands for database inspection
scripts\curl-primeri.bat      # Example curl commands
scripts\test-rate-limit.bat   # Rate limiting test
```

## Tech Stack

- **Backend:** Python 3.11, Flask, SQLAlchemy, Gunicorn
- **Frontend:** React 18, Axios
- **Database:** PostgreSQL 16
- **Proxy:** Nginx (Alpine) with SSL/TLS
- **Containerization:** Docker, Docker Compose
- **Security:** bcrypt, Fernet (AES-256), JWT, RBAC, rate limiting
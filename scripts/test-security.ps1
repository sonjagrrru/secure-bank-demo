# ============================================================
#  SECURITY TESTS - Banking App
#  Run with: .\test-security.ps1
# ============================================================

$API = "https://localhost/api"
$pass = 0
$fail = 0
$total = 0

# Ignore self-signed SSL certificate (dev environment)
try {
    Add-Type @"
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAll {
            public static void Enable() {
                ServicePointManager.ServerCertificateValidationCallback =
                    delegate { return true; };
            }
        }
"@
    [TrustAll]::Enable()
} catch {}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method = "GET",
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = "",
        [int]$Expected,
        [int]$AlsoAccept = 0
    )

    $script:total++

    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ErrorAction = "Stop"
            UseBasicParsing = $true
        }
        if ($Body) {
            $params.Body = $Body
            $params.ContentType = "application/json"
        }

        $response = Invoke-WebRequest @params
        $status = [int]$response.StatusCode
    }
    catch {
        $status = [int]$_.Exception.Response.StatusCode
    }

    if ($status -eq $Expected -or ($AlsoAccept -ne 0 -and $status -eq $AlsoAccept)) {
        $extra = if ($AlsoAccept -ne 0 -and $status -eq $AlsoAccept) { " (rate limit)" } else { "" }
        Write-Host "  [PASSED] $Name -> Status $status$extra" -ForegroundColor Green
        $script:pass++
    }
    else {
        Write-Host "  [FAILED] $Name -> Expected $Expected, got $status" -ForegroundColor Red
        $script:fail++
    }
}

function Get-Token {
    param([string]$Email, [string]$Password)
    try {
        $body = @{ email = $Email; password = $Password } | ConvertTo-Json
        $r = Invoke-RestMethod -Uri "$API/auth/login" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing
        return $r.token
    }
    catch {
        return $null
    }
}

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   SECURITY TESTS - Banking App" -ForegroundColor Cyan
Write-Host "   $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check API
Write-Host "[INFO] Checking if API is available..."
try {
    $h = Invoke-RestMethod -Uri "$API/health" -UseBasicParsing
    Write-Host "[OK] API is available ($($h.status))" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] API is not available! Run setup.bat first." -ForegroundColor Red
    exit 1
}

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 1: Access without token" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "GET /api/accounts without token" -Url "$API/accounts" -Expected 401
Test-Endpoint -Name "POST /api/transactions/transfer without token" -Method "POST" -Url "$API/transactions/transfer" -Body '{"from_account_id":11,"to_account_id":9,"amount":500}' -Expected 401
Test-Endpoint -Name "GET /api/admin/users without token" -Url "$API/admin/users" -Expected 401
Test-Endpoint -Name "GET /api/admin/audit-log without token" -Url "$API/admin/audit-log" -Expected 401

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 2: Fake/invalid token" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "GET /api/accounts with fake token" -Url "$API/accounts" -Headers @{Authorization="Bearer laznitoken123xyz"} -Expected 401
Test-Endpoint -Name "GET /api/accounts with empty Bearer" -Url "$API/accounts" -Headers @{Authorization="Bearer "} -Expected 401
Test-Endpoint -Name "GET /api/accounts without Bearer prefix" -Url "$API/accounts" -Headers @{Authorization="nekitoken"} -Expected 401

# ============================================================
Write-Host ""
Write-Host "[INFO] Logging in users for RBAC tests..."
$tokenCustomer = Get-Token -Email "customer@banking.local" -Password "admin123"
$tokenTeller   = Get-Token -Email "teller@banking.local"   -Password "admin123"
$tokenAdmin    = Get-Token -Email "admin@banking.local"     -Password "admin123"

if (-not $tokenCustomer -or -not $tokenTeller -or -not $tokenAdmin) {
    Write-Host "[ERROR] User login failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Tokens obtained for customer, teller, admin" -ForegroundColor Green

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 3: Customer attempts admin access" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Customer -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403
Test-Endpoint -Name "Customer -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 4: Teller attempts admin access" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Teller -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 403
Test-Endpoint -Name "Teller -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 5: Customer accesses another's account" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Customer views admin account (ID 7)" -Url "$API/accounts/7" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403
Test-Endpoint -Name "Customer transfer from admin account (ID 7)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenCustomer"} -Body '{"from_account_id":7,"to_account_id":11,"amount":100}' -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 6: Teller transfer from another's account" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Teller transfer from customer account (ID 11)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenTeller"} -Body '{"from_account_id":11,"to_account_id":9,"amount":100}' -Expected 403
Test-Endpoint -Name "Teller transfer from OWN account (should pass)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenTeller"} -Body '{"from_account_id":9,"to_account_id":10,"amount":1}' -Expected 200

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 7: Wrong credentials" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Login with wrong password" -Method "POST" -Url "$API/auth/login" -Body '{"email":"admin@banking.local","password":"pogresna"}' -Expected 401
Test-Endpoint -Name "Login with non-existent user" -Method "POST" -Url "$API/auth/login" -Body '{"email":"haker@evil.com","password":"test"}' -Expected 401 -AlsoAccept 429

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GROUP 8: Valid access (should pass)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Admin -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenAdmin"} -Expected 200
Test-Endpoint -Name "Admin -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenAdmin"} -Expected 200
Test-Endpoint -Name "Customer -> GET /api/accounts (own)" -Url "$API/accounts" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 200
Test-Endpoint -Name "Teller -> GET /api/accounts (all)" -Url "$API/accounts" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 200
Test-Endpoint -Name "GET /api/health (public)" -Url "$API/health" -Expected 200

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " TEST RESULTS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total tests:    $total"
Write-Host "  Passed:         $pass" -ForegroundColor Green
Write-Host "  Failed:         $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($fail -eq 0) {
    Write-Host "  >>> ALL SECURITY TESTS PASSED! <<<" -ForegroundColor Green
}
else {
    Write-Host "  >>> WARNING: $fail test(s) failed! <<<" -ForegroundColor Red
}
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

# ============================================================
#  BEZBEDNOSNI TESTOVI - Banking App
#  Pokreni sa: .\test-security.ps1
# ============================================================

$API = "https://localhost/api"
$pass = 0
$fail = 0
$total = 0

# Ignorisi self-signed SSL sertifikat (dev okruzenje)
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
        Write-Host "  [PROSAO] $Name -> Status $status$extra" -ForegroundColor Green
        $script:pass++
    }
    else {
        Write-Host "  [PAO]    $Name -> Ocekivan $Expected, dobijen $status" -ForegroundColor Red
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
Write-Host "   BEZBEDNOSNI TESTOVI - Banking App" -ForegroundColor Cyan
Write-Host "   $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Provera API
Write-Host "[INFO] Provera da li je API dostupan..."
try {
    $h = Invoke-RestMethod -Uri "$API/health" -UseBasicParsing
    Write-Host "[OK] API je dostupan ($($h.status))" -ForegroundColor Green
}
catch {
    Write-Host "[GRESKA] API nije dostupan! Pokrenite setup.bat prvo." -ForegroundColor Red
    exit 1
}

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 1: Pristup bez tokena" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "GET /api/accounts bez tokena" -Url "$API/accounts" -Expected 401
Test-Endpoint -Name "POST /api/transactions/transfer bez tokena" -Method "POST" -Url "$API/transactions/transfer" -Body '{"from_account_id":11,"to_account_id":9,"amount":500}' -Expected 401
Test-Endpoint -Name "GET /api/admin/users bez tokena" -Url "$API/admin/users" -Expected 401
Test-Endpoint -Name "GET /api/admin/audit-log bez tokena" -Url "$API/admin/audit-log" -Expected 401

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 2: Lazni/nevazeci token" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "GET /api/accounts sa laznim tokenom" -Url "$API/accounts" -Headers @{Authorization="Bearer laznitoken123xyz"} -Expected 401
Test-Endpoint -Name "GET /api/accounts sa praznim Bearer" -Url "$API/accounts" -Headers @{Authorization="Bearer "} -Expected 401
Test-Endpoint -Name "GET /api/accounts bez Bearer prefiksa" -Url "$API/accounts" -Headers @{Authorization="nekitoken"} -Expected 401

# ============================================================
Write-Host ""
Write-Host "[INFO] Prijava korisnika za RBAC testove..."
$tokenCustomer = Get-Token -Email "customer@banking.local" -Password "admin123"
$tokenTeller   = Get-Token -Email "teller@banking.local"   -Password "admin123"
$tokenAdmin    = Get-Token -Email "admin@banking.local"     -Password "admin123"

if (-not $tokenCustomer -or -not $tokenTeller -or -not $tokenAdmin) {
    Write-Host "[GRESKA] Neuspesna prijava korisnika!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Tokeni preuzeti za customer, teller, admin" -ForegroundColor Green

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 3: Customer pokusava admin pristup" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Customer -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403
Test-Endpoint -Name "Customer -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 4: Teller pokusava admin pristup" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Teller -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 403
Test-Endpoint -Name "Teller -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 5: Customer pristupa tudjem racunu" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Customer gleda admin racun (ID 7)" -Url "$API/accounts/7" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 403
Test-Endpoint -Name "Customer transfer sa admin racuna (ID 7)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenCustomer"} -Body '{"from_account_id":7,"to_account_id":11,"amount":100}' -Expected 403

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 6: Teller transfer sa tudjeg racuna" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Teller transfer sa customer racuna (ID 11)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenTeller"} -Body '{"from_account_id":11,"to_account_id":9,"amount":100}' -Expected 403
Test-Endpoint -Name "Teller transfer sa SVOG racuna (treba da prodje)" -Method "POST" -Url "$API/transactions/transfer" -Headers @{Authorization="Bearer $tokenTeller"} -Body '{"from_account_id":9,"to_account_id":10,"amount":1}' -Expected 200

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 7: Pogresni kredencijali" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Prijava sa pogresnom lozinkom" -Method "POST" -Url "$API/auth/login" -Body '{"email":"admin@banking.local","password":"pogresna"}' -Expected 401
Test-Endpoint -Name "Prijava sa nepostojecim korisnikom" -Method "POST" -Url "$API/auth/login" -Body '{"email":"haker@evil.com","password":"test"}' -Expected 401 -AlsoAccept 429

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " TEST GRUPA 8: Validni pristupi (treba da prodju)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Test-Endpoint -Name "Admin -> GET /api/admin/users" -Url "$API/admin/users" -Headers @{Authorization="Bearer $tokenAdmin"} -Expected 200
Test-Endpoint -Name "Admin -> GET /api/admin/audit-log" -Url "$API/admin/audit-log" -Headers @{Authorization="Bearer $tokenAdmin"} -Expected 200
Test-Endpoint -Name "Customer -> GET /api/accounts (svoj)" -Url "$API/accounts" -Headers @{Authorization="Bearer $tokenCustomer"} -Expected 200
Test-Endpoint -Name "Teller -> GET /api/accounts (svi)" -Url "$API/accounts" -Headers @{Authorization="Bearer $tokenTeller"} -Expected 200
Test-Endpoint -Name "GET /api/health (javni)" -Url "$API/health" -Expected 200

# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " REZULTAT TESTOVA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Ukupno testova:  $total"
Write-Host "  Proslo:          $pass" -ForegroundColor Green
Write-Host "  Palo:            $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($fail -eq 0) {
    Write-Host "  >>> SVI BEZBEDNOSNI TESTOVI SU PROSLI! <<<" -ForegroundColor Green
}
else {
    Write-Host "  >>> UPOZORENJE: $fail test(ova) je palo! <<<" -ForegroundColor Red
}
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

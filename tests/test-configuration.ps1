```powershell
# ============================================================
# Defender → Tenable Security Automation
# Configuration Validation Test
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $RepositoryRoot "config\config.ps1"

Write-Host "=============================================="
Write-Host " Configuration Validation"
Write-Host "=============================================="

if (-not (Test-Path $ConfigPath)) {
    Write-Host "FAIL: config/config.ps1 was not found." -ForegroundColor Red
    exit 1
}

try {
    . $ConfigPath
}
catch {
    Write-Host "FAIL: Unable to load configuration." -ForegroundColor Red
    exit 1
}

$requiredVariables = @(
    "TenableAccessKey",
    "TenableSecretKey",
    "TenableBaseUrl",
    "DefenderLogName",
    "DefenderEventId",
    "LogDirectory",
    "ReportDirectory",
    "LastRecordIdFile"
)

$failed = $false

foreach ($variableName in $requiredVariables) {
    $exists = Get-Variable -Name $variableName -Scope Global -ErrorAction SilentlyContinue

    if (-not $exists) {
        Write-Host "FAIL: Missing configuration variable: $variableName" -ForegroundColor Red
        $failed = $true
        continue
    }

    $value = $exists.Value

    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        Write-Host "FAIL: Empty configuration variable: $variableName" -ForegroundColor Red
        $failed = $true
    }
}

if ($TenableBaseUrl -notmatch "^https://") {
    Write-Host "FAIL: TenableBaseUrl must use HTTPS." -ForegroundColor Red
    $failed = $true
}

if ([int]$DefenderEventId -ne 1116) {
    Write-Host "FAIL: DefenderEventId must be 1116." -ForegroundColor Red
    $failed = $true
}

if (-not $failed) {
    Write-Host ""
    Write-Host "PASS: Configuration structure is valid." -ForegroundColor Green
    Write-Host "Secrets were not displayed."
    exit 0
}

Write-Host ""
Write-Host "Configuration validation failed." -ForegroundColor Red
exit 1
```

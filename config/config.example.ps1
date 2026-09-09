```powershell
# ============================================================
# Defender → Tenable Security Automation
# Example Configuration
# ============================================================
#
# Copy this file to:
#   config/config.ps1
#
# Never commit config/config.ps1 to Git.
# ============================================================

# ------------------------------------------------------------
# Tenable.io Configuration
# ------------------------------------------------------------

$TenableAccessKey = "YOUR_TENABLE_ACCESS_KEY"
$TenableSecretKey = "YOUR_TENABLE_SECRET_KEY"

$TenableBaseUrl = "https://cloud.tenable.com"

# ------------------------------------------------------------
# Microsoft Defender Configuration
# ------------------------------------------------------------

$DefenderLogName = "Microsoft-Windows-Windows Defender/Operational"
$DefenderEventId = 1116

# ------------------------------------------------------------
# Local Directories
# ------------------------------------------------------------

$LogDirectory    = "C:\logs\defender-events-csv-1116"
$ReportDirectory = "C:\logs\defender-events-csv-1116"

$LogFilePath     = Join-Path $LogDirectory "DefenderLog.txt"
$ErrorLogFile    = Join-Path $LogDirectory "ErrorLog.txt"
$LastRecordIdFile = Join-Path $LogDirectory "LastRecordId.txt"

# ------------------------------------------------------------
# Queue / State
# ------------------------------------------------------------

$QueueFile = Join-Path $LogDirectory "ScanQueue.json"

# ------------------------------------------------------------
# Polling Intervals
# ------------------------------------------------------------

$DefenderPollingSeconds = 10
$ScanPollingSeconds     = 10
$ExportPollingSeconds   = 5

# ------------------------------------------------------------
# Timeout Configuration
# ------------------------------------------------------------

$ScanTimeoutMinutes   = 120
$ExportTimeoutMinutes = 30

# ------------------------------------------------------------
# Retry Configuration
# ------------------------------------------------------------

$MaxApiRetries    = 3
$RetryDelaySeconds = 5
```

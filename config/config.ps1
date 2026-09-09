$TenableAccessKey = "YOUR_REAL_ACCESS_KEY"
$TenableSecretKey = "YOUR_REAL_SECRET_KEY"

$TenableBaseUrl = "https://cloud.tenable.com"

$DefenderLogName = "Microsoft-Windows-Windows Defender/Operational"
$DefenderEventId = 1116

$LogDirectory    = "C:\logs\defender-events-csv-1116"
$ReportDirectory = "C:\logs\defender-events-csv-1116"

$LogFilePath      = Join-Path $LogDirectory "DefenderLog.txt"
$ErrorLogFile     = Join-Path $LogDirectory "ErrorLog.txt"
$LastRecordIdFile = Join-Path $LogDirectory "LastRecordId.txt"

$QueueFile = Join-Path $LogDirectory "ScanQueue.json"

$DefenderPollingSeconds = 10
$ScanPollingSeconds     = 10
$ExportPollingSeconds   = 5

$ScanTimeoutMinutes   = 120
$ExportTimeoutMinutes = 30

$MaxApiRetries     = 3
$RetryDelaySeconds = 5
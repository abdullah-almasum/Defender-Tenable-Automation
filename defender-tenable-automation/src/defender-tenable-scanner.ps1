# ---------------------------------------------
# PowerShell Script: Tenable Scan Integration with Main Menu
# ---------------------------------------------

# Check if running as Administrator
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    # Show popup message
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "🚫 This script must be run as Administrator. Right-click the script and choose 'Run with PowerShell as Administrator'.",
        "Administrator Access Required",
        'OK',
        'Error'
    )
    exit
}

# --- Configuration Section ---
$TenableAccessKey = "YOUR_TENABLE_ACCESS_KEY"
$TenableSecretKey = "YOUR_TENABLE_SECRET_KEY"
$ExportDir        = "C:\logs\defender-events-csv-1116"

$LogFilePath      = Join-Path $ExportDir "DefenderLog.txt"
$LastEventIdFile  = Join-Path $ExportDir "LastRecordId.txt"
$ErrorLogFile     = Join-Path $ExportDir "ErrorLog.txt"

#API Header Setup
$headers = @{
    "X-ApiKeys"    = "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey"
    "Content-Type" = "application/json"
}

# --- Ensure directories and log files exist ---
if (!(Test-Path $ExportDir)) { New-Item -Path $ExportDir -ItemType Directory -Force | Out-Null }
if (!(Test-Path $LastEventIdFile)) { Set-Content -Path $LastEventIdFile -Value "0" }
if (!(Test-Path $ErrorLogFile)) { New-Item -Path $ErrorLogFile -ItemType File -Force | Out-Null }

# Global variables for queue and scan lock
$Global:scanQueue = [System.Collections.Queue]::new()
$Global:isScanRunning = $false

function Start-Scan {
    param (
        [int]$scanId
    )
    try {
        Write-Host "🔄 Launching scan ID: $scanId ..."
        $launchUri = "https://cloud.tenable.com/scans/$scanId/launch"
        $response = Invoke-RestMethod -Method Post -Uri $launchUri -Headers $headers -ErrorAction Stop

        if (-not $response.scan_uuid) {
            throw "No scan UUID returned."
        }

        $scanUuid = $response.scan_uuid
        Write-Host "✅ Scan triggered (UUID: $scanUuid)"

        # Wait for scan completion
        $scanStatusUri = "https://cloud.tenable.com/scans/$scanId"
        do {
            Start-Sleep -Seconds 10
            $scanStatus = Invoke-RestMethod -Method Get -Uri $scanStatusUri -Headers $headers
            $status = $scanStatus.info.status
            Write-Host "$(Get-Date -Format 'HH:mm:ss') ⏳ Scan status: $status"
        } while ($status -ne "completed")

        Write-Host "$(Get-Date -Format 'HH:mm:ss') ✅ Scan completed. Exporting CSV report..."

        # Export CSV
        $exportUrl = "https://cloud.tenable.com/scans/$scanId/export"
        $body = @{ format = "csv" } | ConvertTo-Json
        $exportResponse = Invoke-RestMethod -Method Post -Uri $exportUrl -Headers $headers -Body $body
        $fileId = $exportResponse.file

        # Wait for export readiness
        do {
            Start-Sleep -Seconds 5
            $fileStatus = Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/status" -Headers $headers
        } while ($fileStatus.status -ne "ready")

        # Save CSV with numbering
        $existingFiles = Get-ChildItem -Path $ExportDir -Filter "Auto_TenableReport_${scanId}_*.csv" -ErrorAction SilentlyContinue
        $nextNumber = if ($existingFiles) {
            ($existingFiles | ForEach-Object {
                if ($_ -match "Auto_TenableReport_${scanId}_(\d+)\.csv") { [int]$matches[1] } else { 0 }
            } | Measure-Object -Maximum).Maximum + 1
        } else {
            1
        }

        $csvPath = Join-Path $ExportDir ("Auto_TenableReport_${scanId}_$nextNumber.csv")
        Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/download" -Headers $headers -OutFile $csvPath
        Write-Host "📁 CSV Report saved to: $csvPath"
    }
    catch {
        $errMsg = "$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) ❌ Error scanning ${scanId}: $($_.Exception.Message)"
        Add-Content -Path $ErrorLogFile -Value $errMsg
        Write-Host $errMsg -ForegroundColor Red
    }
}

function Process-ScanQueue {
    while ($Global:scanQueue.Count -gt 0) {
        $Global:isScanRunning = $true
        $currentScanId = $Global:scanQueue.Dequeue()
        Start-Scan -scanId $currentScanId
    }
    $Global:isScanRunning = $false
}

function Enqueue-Scan {
    param (
        [int]$scanId
    )
    if ($Global:isScanRunning) {
        Write-Host "⏳ Scan running. Queuing scan ID: $scanId"
        $Global:scanQueue.Enqueue($scanId)
    } else {
        Write-Host "▶️ Starting scan ID: $scanId immediately."
        $Global:scanQueue.Enqueue($scanId)
        Process-ScanQueue
    }
}

function Start-Monitoring {
    Write-Host "`nAvailable Scans:"
    $scans = Invoke-RestMethod -Method Get -Uri "https://cloud.tenable.com/scans" -Headers $headers
    $scans.scans | Select-Object @{Name="Scan ID";Expression={$_.id}}, @{Name="Name";Expression={$_.name}}, @{Name="Status";Expression={$_.status}} | Format-Table -AutoSize

    $scanId = Read-Host "`nEnter the Scan ID to use for scanning"

    if (-not [int]::TryParse($scanId, [ref]$null)) {
        Write-Host "❌ Invalid Scan ID. Returning to main menu."
        return
    }

    Write-Host "🚀 Starting Defender Event 1116 monitoring in background..."

    Start-Job -ScriptBlock {
        param($LogFilePath, $LastEventIdFile, $ErrorLogFile, $headers, $scanId, $ExportDir)

        $Global:scanQueue = [System.Collections.Queue]::new()
        $Global:isScanRunning = $false

        function Start-Scan {
            param ([int]$scanId)

            try {
                Write-Host "🔄 Launching scan ID: $scanId ..."
                $launchUri = "https://cloud.tenable.com/scans/$scanId/launch"
                $response = Invoke-RestMethod -Method Post -Uri $launchUri -Headers $headers -ErrorAction Stop

                if (-not $response.scan_uuid) { throw "No scan UUID returned." }
                $scanUuid = $response.scan_uuid
                Write-Host "✅ Scan triggered (UUID: $scanUuid)"

                $scanStatusUri = "https://cloud.tenable.com/scans/$scanId"
                do {
                    Start-Sleep -Seconds 10
                    $scanStatus = Invoke-RestMethod -Method Get -Uri $scanStatusUri -Headers $headers
                    $status = $scanStatus.info.status
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') ⏳ Scan status: $status"
                } while ($status -ne "completed")

                Write-Host "$(Get-Date -Format 'HH:mm:ss') ✅ Scan completed. Exporting CSV report..."

                $exportUrl = "https://cloud.tenable.com/scans/$scanId/export"
                $body = @{ format = "csv" } | ConvertTo-Json
                $exportResponse = Invoke-RestMethod -Method Post -Uri $exportUrl -Headers $headers -Body $body
                $fileId = $exportResponse.file

                do {
                    Start-Sleep -Seconds 5
                    $fileStatus = Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/status" -Headers $headers
                } while ($fileStatus.status -ne "ready")

                $existingFiles = Get-ChildItem -Path $ExportDir -Filter "Auto_TenableReport_${scanId}_*.csv" -ErrorAction SilentlyContinue
                $nextNumber = if ($existingFiles) {
                    ($existingFiles | ForEach-Object {
                        if ($_ -match "Auto_TenableReport_${scanId}_(\d+)\.csv") { [int]$matches[1] } else { 0 }
                    } | Measure-Object -Maximum).Maximum + 1
                } else { 1 }

                $csvPath = Join-Path $ExportDir ("Auto_TenableReport_${scanId}_$nextNumber.csv")
                Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/download" -Headers $headers -OutFile $csvPath
                Write-Host "📁 CSV Report saved to: $csvPath"
            }
            catch {
                $errMsg = "$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) ❌ Error scanning ${scanId}: $($_.Exception.Message)"
                Add-Content -Path $ErrorLogFile -Value $errMsg
                Write-Host $errMsg -ForegroundColor Red
            }
        }

        function Process-ScanQueue {
            while ($Global:scanQueue.Count -gt 0) {
                $Global:isScanRunning = $true
                $currentScanId = $Global:scanQueue.Dequeue()
                Start-Scan -scanId $currentScanId
            }
            $Global:isScanRunning = $false
        }

        function Enqueue-Scan {
            param ([int]$scanId)
            if ($Global:isScanRunning) {
                Write-Host "⏳ Scan running. Queuing scan ID: $scanId"
                $Global:scanQueue.Enqueue($scanId)
            } else {
                Write-Host "▶️ Starting scan ID: $scanId immediately."
                $Global:scanQueue.Enqueue($scanId)
                Process-ScanQueue
            }
        }

        # On first run, get all past Defender Event ID 1116 with RecordId > last handled
        $lastId = 0
        if (Test-Path $LastEventIdFile) {
            $lastId = [int](Get-Content -Path $LastEventIdFile).Trim()
        } else {
            Set-Content -Path $LastEventIdFile -Value "0"
        }

        $pastEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -FilterXPath "*[System[(EventID=1116)]]" -MaxEvents 1000 |
            Where-Object { $_.RecordId -gt $lastId } | Sort-Object RecordId

        foreach ($event in $pastEvents) {
            $recordId = $event.RecordId
            $timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $logLine = "$timestamp - EventID: 1116 - RecordID: $recordId - $($event.Message)"
            Add-Content -Path $LogFilePath -Value $logLine
            Set-Content -Path $LastEventIdFile -Value $recordId
            Write-Host "Detected past event RecordID $recordId, queueing scan ID $scanId"
            Enqueue-Scan -scanId $scanId
        }

        Write-Host "✅ Completed initial past events scan queue."

        while ($true) {
            try {
                # Check for new events after last processed RecordId
                $lastId = [int](Get-Content -Path $LastEventIdFile).Trim()
                $newEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -FilterXPath "*[System[(EventID=1116)]]" -MaxEvents 10 |
                    Where-Object { $_.RecordId -gt $lastId } | Sort-Object RecordId

                foreach ($event in $newEvents) {
                    $recordId = $event.RecordId
                    $timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $logLine = "$timestamp - EventID: 1116 - RecordID: $recordId - $($event.Message)"
                    Add-Content -Path $LogFilePath -Value $logLine
                    Set-Content -Path $LastEventIdFile -Value $recordId
                    Write-Host "New event RecordID $recordId detected, queueing scan ID $scanId"
                    Enqueue-Scan -scanId $scanId
                }
            }
            catch {
                $errMsg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ❗ Error during event polling: $($_.Exception.Message)"
                Add-Content -Path $ErrorLogFile -Value $errMsg
                Write-Host $errMsg -ForegroundColor Red
            }

            Start-Sleep -Seconds 10
        }
    } -ArgumentList $LogFilePath, $LastEventIdFile, $ErrorLogFile, $headers, $scanId, $ExportDir

    Write-Host "`n📢 Monitoring started in background. Press Ctrl+C to stop anytime."
}

function Export-ScanCSV {
    try {
        $scans = Invoke-RestMethod -Method Get -Uri "https://cloud.tenable.com/scans" -Headers $headers

        Write-Host "`n📋 Available Scans:" -ForegroundColor Cyan
        Write-Host "--------------------------------------------------------"
        $scans.scans | Select-Object `
            @{Name = "Scan ID"; Expression = { $_.id } },
            @{Name = "Scan Name"; Expression = { $_.name } },
            @{Name = "Status"; Expression = { $_.status } } |
            Format-Table -AutoSize
        Write-Host "--------------------------------------------------------"

        $scanId = Read-Host "`nEnter the Scan ID to export report as CSV (or press Enter to skip)"
        if (-not $scanId) {
            Write-Host "`n⏩ Skipping export. Returning to main menu..." -ForegroundColor Yellow
            return
        }

        # Trigger export
        $exportUrl = "https://cloud.tenable.com/scans/$scanId/export"
        $body = @{ format = "csv" } | ConvertTo-Json
        $exportResponse = Invoke-RestMethod -Method Post -Uri $exportUrl -Headers $headers -Body $body
        $fileId = $exportResponse.file

        Write-Host "⏳ Waiting for report to be ready..." -ForegroundColor DarkYellow
        do {
            Start-Sleep -Seconds 5
            $status = Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/status" -Headers $headers
        } while ($status.status -ne "ready")

        # Generate next serial number based on existing files
        $existingFiles = Get-ChildItem -Path $ExportDir -Filter "TenableReport_${scanId}_*.csv" -ErrorAction SilentlyContinue
        $serial = ($existingFiles.Count + 1)

        $csvFileName = "TenableReport_${scanId}_${serial}.csv"
        $csvPath = Join-Path $ExportDir $csvFileName

        # Download file
        Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/download" -Headers $headers -OutFile $csvPath

        Write-Host "`n✅ Report downloaded successfully to: $csvPath" -ForegroundColor Green
    } catch {
        Write-Host "`n❌ Failed to download CSV report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ---------------------------
# MAIN MENU LOOP
# ---------------------------
while ($true) {
    Clear-Host
    Write-Host "=============================================="
    Write-Host "🛡️  Tenable Scanner Interactive Menu"
    Write-Host "=============================================="
    Write-Host "1. Monitor Windows Defender Event ID 1116 and Trigger Scan"
    Write-Host "2. Export CSV Report from a Specific Scan"
    Write-Host "3. Exit Program"
    Write-Host "=============================================="

    $choice = Read-Host "Select an option (1-3)"

    switch ($choice) {
        "1" {
            $startProgram = Read-Host "`nDo you want to start the program to monitor Event ID 1116? (Yes/No)"
            if ($startProgram -ieq "Yes") {
                Start-Monitoring
                Pause
            }
            elseif ($startProgram -ieq "No") {
                Write-Host "`nYou chose to skip the program. Returning to the main menu..."
                Start-Sleep -Seconds 2
            }
            else {
                Write-Host "`nInvalid input. Please enter 'Yes' or 'No'."
                Pause
            }
        }
        "2" {
            $startProgram = Read-Host "`nDo you want to export a CSV report? (Yes/No)"
            if ($startProgram -ieq "Yes") {
                Export-ScanCSV
                Pause
            }
            elseif ($startProgram -ieq "No") {
                Write-Host "`nYou chose to skip the program. Returning to the main menu..."
                Start-Sleep -Seconds 2
            }
            else {
                Write-Host "`nInvalid input. Please enter 'Yes' or 'No'."
                Pause
            }
        }
        "3" {
            $backgroundJobs = Get-Job -State "Running" -ErrorAction SilentlyContinue
            if ($backgroundJobs.Count -gt 0) {
                Write-Host "`n⚠️ Warning: Background monitoring jobs are still running!"
                foreach ($job in $backgroundJobs) {
                    Write-Host "`n🛑 Stopping background job with ID: $($job.Id) - $($job.Name)..."
                    Stop-Job -Job $job
                    Remove-Job -Job $job
                    Write-Host "✅ Job ID $($job.Id) stopped successfully."
                }
                Write-Host "`nAll background monitoring jobs have been stopped."
            }
            else {
                Write-Host "`nNo background monitoring jobs are running."
            }
            Write-Host "`n👋 Exiting the program. Stay secure!"
            exit
        }
        default {
            Write-Host "⚠️ Invalid choice. Please try again." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

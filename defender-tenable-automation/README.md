# Tenable Scanner Interactive Menu with automatic CSV export after scan completion

### The final script includes:

- 🕵️ **First-time scan of all past Defender Event ID 1116 events**
- 🔄 **Continuous real-time monitoring for new events**
- 🕓 **Waits for scan completion before starting the next**
- 🧾 **Exports CSV with dynamic naming: `Auto_TenableReport_<ScanID>_<Serial>.csv`**
- 📜 **Complete menu system with option to monitor, export manually, or exit**
- 📦 **Proper queuing system to avoid overlapping scans**

```python
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
$TenableAccessKey = "1799d80269c19696cfd485757e0ad5ed35302f0bf5a724ca367c5478d140e41c"
$TenableSecretKey = "1acb69b45551ba53ea320c4ef54dcea0f7f080bc3f2b1a8bed2e5f308ce10131"
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
```

### Create a `.bat` File to Run It

```powershell
@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Smart Security\Desktop\defender-events-csv-1116.ps1"
pause
```

```json
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\defender-events-csv-1116.ps1"
```

### What this full script does:

- **First run:** Detects *all* past Defender Event ID 1116 with RecordId > last processed and queues scans one-by-one.
- **Scan queue system:** Ensures only one scan runs at a time; new events queue while a scan runs.
- **Scan completion:** Waits for scan completion, then auto-exports the CSV report with a filename format like
    
    `Auto_TenableReport_<scanID>_<serialNumber>.csv`.
    
- **Continuous monitoring:** Watches for new events, queues scans accordingly.
- **Menu system:** Lets you start monitoring, export CSV manually, or exit (which stops any running jobs cleanly).
- **Logs:** Maintains logs for Defender events and errors.
- **Graceful job handling:** Stops background jobs properly on exit.

### Explain Code

### 🧾 **1. Configuration Section**

```powershell
$TenableAccessKey = "..."  # Your API Access Key
$TenableSecretKey = "..."  # Your API Secret Key
$ExportDir        = "C:\logs\defender-events-csv-1116"
```

**Purpose:** These variables hold credentials and paths used throughout the script. The `$ExportDir` is where logs and reports will be stored.

### 📁 **2. Ensure Directory & Log Files Exist**

```powershell
# --- Ensure directories and log files exist ---
if (!(Test-Path $ExportDir)) { New-Item -Path $ExportDir -ItemType Directory -Force | Out-Null }
if (!(Test-Path $LastEventIdFile)) { Set-Content -Path $LastEventIdFile -Value "0" }
if (!(Test-Path $ErrorLogFile)) { New-Item -Path $ErrorLogFile -ItemType File -Force | Out-Null }
```

**Purpose:** Ensures log directory and state files (`LastRecordId.txt`, etc.) exist. If not, it creates them.

### 🔐 **3. API Header Setup**

```powershell
$headers = @{
    "X-ApiKeys"    = "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey"
    "Content-Type" = "application/json"
}
```

**Purpose:** Used in API calls to authenticate with Tenable.io.

### 📡 **4. Job Queue Management (Global)**

```powershell
$Global:ScanQueue = [System.Collections.Queue]::new()
$Global:IsScanRunning = $false
```

**Purpose:**

- `$ScanQueue` handles sequential scan jobs.
- `$IsScanRunning` ensures scans don’t overlap.

### 🛰️ **5. Start-Monitoring Function**

✅ Scan ID Selection

```powershell
param ([int]$scanId)
scanId: the ID of the Tenable scan to be launched.
```

### 🚀 **Launching the scan**

```powershell
$launchUri = "https://cloud.tenable.com/scans/$scanId/launch"
$response = Invoke-RestMethod -Method Post -Uri $launchUri -Headers $headers -ErrorAction Stop
```

- Constructs the URI to launch the scan.
- Sends a **POST** request to start the scan.
- `$headers` should contain the API token for authentication.

### ✅ **Check for Scan UUID**

```powershell
if (-not $response.scan_uuid) {
    throw "No scan UUID returned."
}
```

- Ensures Tenable returned a scan UUID.
- If not, throws an error and jumps to the `catch` block.

### ⏳ **Polling for Scan Completion**

```powershell
$scanStatusUri = "https://cloud.tenable.com/scans/$scanId"
do {
    Start-Sleep -Seconds 10
    $scanStatus = Invoke-RestMethod -Method Get -Uri $scanStatusUri -Headers $headers
    $status = $scanStatus.info.status
    Write-Host "$(Get-Date -Format 'HH:mm:ss') ⏳ Scan status: $status"
} while ($status -ne "completed")
```

- Loops every 10 seconds.
- Checks scan status.
- Waits until the status is `"completed"`.

### 📤 **Request CSV Export**

```powershell
$exportUrl = "https://cloud.tenable.com/scans/$scanId/export"
$body = @{ format = "csv" } | ConvertTo-Json
$exportResponse = Invoke-RestMethod -Method Post -Uri $exportUrl -Headers $headers -Body $body
$fileId = $exportResponse.file
```

- Sends a request to export scan results in CSV format.
- Captures the `fileId` for the export file.

### ⏳ **Wait for Export File to be Ready**

```powershell
do {
    Start-Sleep -Seconds 5
    $fileStatus = Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/status" -Headers $headers
} while ($fileStatus.status -ne "ready"
```

- Polls every 5 seconds.
- Waits for the file to be ready for download.

### 💾 **Save CSV with Incremental File Name**

```powershell
$existingFiles = Get-ChildItem -Path $ExportDir -Filter "Auto_TenableReport_${scanId}_*.csv" -ErrorAction SilentlyContinue
```

- Searches for existing reports of the same scan ID.

```powershell
nextNumber = if ($existingFiles) {
    ($existingFiles | ForEach-Object {
        if ($_ -match "Auto_TenableReport_${scanId}_(\d+)\.csv") { [int]$matches[1] } else { 0 }
    } | Measure-Object -Maximum).Maximum + 1
} else {
    1
}
```

- Determines the next serial number by checking the existing CSVs.

```powershell
csvPath = Join-Path $ExportDir ("Auto_TenableReport_${scanId}_$nextNumber.csv")
Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/download" -Headers $headers -OutFile $csvPath
```

- Downloads the file to `$csvPath`.

### 🛑 **Error Handling**

```powershell
catch {
    $errMsg = "$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) ❌ Error scanning ${scanId}: $($_.Exception.Message)"
    Add-Content -Path $ErrorLogFile -Value $errMsg
    Write-Host $errMsg -ForegroundColor Red
}
```

- Logs any error to `$ErrorLogFile`.
- Prints the error to the console in red.

### 🔁 `Process-ScanQueue`

This function **processes queued scan jobs one-by-one**, ensuring only **one scan runs at a time**.

```powershell
while ($Global:scanQueue.Count -gt 0) {
#Keeps running as long as there are scan IDs in the queue.
```

```powershell
$Global:isScanRunning = $true
#A global flag used to prevent launching multiple scans simultaneously.
```

```powershell
$currentScanId = $Global:scanQueue.Dequeue()
#Removes the first scan ID from the queue.
```

```powershell
Start-Scan -scanId $currentScanId
#Calls your earlier-defined Start-Scan function to launch and complete the scan.
```

```powershell
$Global:isScanRunning = $false
#Once the queue is empty, resets the global flag so that new scans can be triggered again.
```

### 🔁 `Process-ScanQueue` — *Scan Executor*

**What it does:**

- Continuously runs while there are items in the global scan queue (`$Global:scanQueue`).
- Sets `$Global:isScanRunning = $true` while scanning.
- Takes one scan ID at a time from the queue (`Dequeue()`), and launches the scan using `Start-Scan`.
- After the queue is empty, it sets `$Global:isScanRunning = $false`.

### 📥 `Enqueue-Scan`

This function **adds scans to the queue** and decides whether to start immediately or wait.

```powershell
param ([int]$scanId)
#Accepts a scan ID to add to the queue.
```

```powershell
if ($Global:isScanRunning) {
#Checks whether a scan is currently running.
```

```powershell
Write-Host "⏳ Scan running. Queuing scan ID: $scanId"
$Global:scanQueue.Enqueue($scanId)
#If busy, just queue the new scan and wait.
```

```powershell
rite-Host "▶️ Starting scan ID: $scanId immediately."
$Global:scanQueue.Enqueue($scanId)
Process-ScanQueue
#If no scan is running, enqueue and immediately call Process-ScanQueue to process it.
```

### ➕ `Enqueue-Scan` — *Scan Request Handler*

**What it does:**

- Adds a new scan ID to the queue.
- If a scan is already running:
    - It **just queues** the new scan (`Enqueue()`).
- If **no scan is running**:
    - It **queues the scan** and then **immediately starts `Process-ScanQueue`**.

### 📦 How They Work Together

- `Enqueue-Scan` is the **input** — called when a scan needs to be triggered.
- `Process-ScanQueue` is the **executor** — actually runs scans from the queue, one at a time.
- This ensures **no scans run in parallel** (avoids overloading Tenable or system resources).

> **This `Start-Monitoring` function is a PowerShell automation powerhouse — it starts a background job that watches for Microsoft Defender Event ID 1116 (threats detected), automatically launches a Tenable.io scan, and exports a uniquely numbered CSV report.**
> 

### 🔍 PART 1: **User Interaction & Setup**

```powershell
powershell
CoWrite-Host "`nAvailable Scans:"
$scans = Invoke-RestMethod -Method Get -Uri "https://cloud.tenable.com/scans" -Headers $headers
```

- Lists available scans via Tenable.io API.

```powershell
$scans.scans | Select-Object @{Name="Scan ID";Expression={$_.id}}, @{Name="Name";Expression={$_.name}}, @{Name="Status";Expression={$_.status}} | Format-Table -AutoSize
```

- Displays Scan ID, Name, and Status in table format.

```powershell
$scanId = Read-Host "`nEnter the Scan ID to use for scanning"
```

- Asks user to choose a scan ID that will be used every time Event ID 1116 occurs.

```powershell
if (-not [int]::TryParse($scanId, [ref]$null)) {
    Write-Host "❌ Invalid Scan ID. Returning to main menu."
    return
}
```

- Validates input. Returns if not a number.

## 🔧 PART 2: **Background Job for Continuous Monitoring**

```powershell
Start-Job -ScriptBlock { ... } -ArgumentList $LogFilePath, $LastEventIdFile, $ErrorLogFile, $headers, $scanId, $ExportDir
```

- Launches the continuous monitoring in the background.

### 🧠 INTERNALS OF THE BACKGROUND JOB

🔁 **1. Queueing system**

Declares:

```powershell
$Global:scanQueue = [System.Collections.Queue]::new()
$Global:isScanRunning = $false
```

Creates a scan queue and lock flag so that only one scan runs at a time.

Includes:

- `Start-Scan` (launches scan and exports CSV)
- `Process-ScanQueue` (dequeues and processes scans)
- `Enqueue-Scan` (queues scan and triggers processing if idle)

### 🕰️ **2. First-run: Past EventID 1116 Detection**

```powershell
$lastId = 0
if (Test-Path $LastEventIdFile) {
    $lastId = [int](Get-Content -Path $LastEventIdFile).Trim()
} else {
    Set-Content -Path $LastEventIdFile -Value "0"
}
```

- Keeps track of the **last processed event RecordId** in a file for persistence.

```powershell
$pastEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -FilterXPath "*[System[(EventID=1116)]]" -MaxEvents 1000 |
    Where-Object { $_.RecordId -gt $lastId } | Sort-Object RecordId
```

- Loads recent Event ID 1116 entries (up to 1000) not previously processed.

```powershell
foreach ($event in $pastEvents) {
    ...
    Enqueue-Scan -scanId $scanId
}
```

- Logs each event and queues the scan.

### 🔄 **3. Real-time Polling (Every 10s)**

```powershell
while ($true) {
    ...  $newEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -FilterXPath "*[System[(EventID=1116)]]" -MaxEvents 10 |
                    Where-Object { $_.RecordId -gt $lastId } | Sort-Object RecordId
    $newEvents = Get-WinEvent ...
}
```

- Runs **forever**.
- Every 10 seconds checks for **new 1116 events**.
- Pulls **up to 10 recent Defender events** (EventID 1116)
- Filters out anything that was already processed
- Sorts the new detections for clean processing

```powershell
foreach ($event in $newEvents) {
    ...
    Enqueue-Scan -scanId $scanId
}
 Start-Sleep -Seconds 10
 ...
  Write-Host "`n📢 Monitoring started in background. Press Ctrl+C to stop anytime."
}
```

- Logs & queues each new detection.

### 📁 Logging

- `$LogFilePath` — logs each detection.
- `$LastEventIdFile` — remembers last handled event.
- `$ErrorLogFile` — stores any runtime errors (network, scan errors, etc.)

### Export CSV Report from a Specific Scan

1. **Retrieve Scan List**

```powershell
$scans = Invoke-RestMethod -Method Get -Uri "https://cloud.tenable.com/scans" -Headers $headers
```

- Authenticates with the Tenable API using your `$headers`.
- Retrieves the list of **all available scans** in your Tenable.io account.

2. **Display Scan Table to User**

```powershell
$scans.scans | Select-Object ... | Format-Table -AutoSize
```

- Extracts: Scan ID, Scan Name, and Status.
- Formats them into a human-readable table for easier selection.

3. **User Input: Choose Scan to Export**

```powershell
$scanId = Read-Host "`nEnter the Scan ID to export report as CSV (or press Enter to skip)"
```

- Prompts the user to enter a Scan ID.
- If user presses Enter (input is empty), the function skips the export and returns to the menu.

4. **Trigger Export (Request CSV Generation)**

```powershell
$exportUrl = "https://cloud.tenable.com/scans/$scanId/export"
$body = @{ format = "csv" } | ConvertTo-Json
$exportResponse = Invoke-RestMethod -Method Post -Uri $exportUrl -Headers $headers -Body $body
```

- Sends a POST request to export the scan report in **CSV** format.
- Saves the response, which includes a `file` ID for download tracking.

5. **Poll for Export Readiness**

```powershell
do {
    Start-Sleep -Seconds 5
    $status = Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/status" -Headers $headers
} while ($status.status -ne "ready")
```

- Keeps checking the status every 5 seconds until the CSV file is ready for download.

6. **Generate Unique Filename (with Serial Number)**

```powershell
$existingFiles = Get-ChildItem -Path $ExportDir -Filter "TenableReport_${scanId}_*.csv"
$serial = ($existingFiles.Count + 1)
$csvFileName = "TenableReport_${scanId}_${serial}.csv"
$csvPath = Join-Path $ExportDir $csvFileName
```

- Looks in `$ExportDir` for existing reports with the same Scan ID.
- Adds `+1` to the count to generate a unique filename like `TenableReport_3456_2.csv`.

7. **Download the CSV File**

```powershell
Invoke-RestMethod -Method Get -Uri "$exportUrl/$fileId/download" -Headers $headers -OutFile $csvPath
```

- Actually downloads the CSV file to the designated export path.

8. **Success or Error Message**

```powershell
Write-Host "`n✅ Report downloaded successfully to: $csvPath"
```

- Confirms a successful export.

If anything fails:

```powershell
catch {
    Write-Host "`n❌ Failed to download CSV report: $($_.Exception.Message)"
}
```

- Catches errors and prints the message.

Summery 

- Listing scans,
- Letting the user choose one,
- Exporting it as CSV,
- Saving the file with a unique name.

### 🟢 Option 1: Start Defender Monitoring + Scanning

```powershell
"1" {
    $startProgram = Read-Host "`nDo you want to start the program to monitor Event ID 1116? (Yes/No)"
    if ($startProgram -ieq "Yes") {
        Start-Monitoring
        Pause
    }
```

- Asks for confirmation before starting.
- If user says `Yes`, calls `Start-Monitoring` which:
    - Scans all past Defender Event 1116s,
    - Queues scans,
    - Monitors in real time (in the background via `Start-Job`).
- `Pause` gives time to read output before returning.

`ieq` in PowerShell means:

> Case-insensitive equality comparison.
> 
- It is short for: **`i` (ignore case) + `eq` (equals)**

⚠️ Compare with:

`eq` → **case-sensitive**

`ieq` → **case-insensitive**

### 🟡 Option 2: Export CSV

```powershell
"2" {
    $startProgram = Read-Host "`nDo you want to export a CSV report? (Yes/No)"
    if ($startProgram -ieq "Yes") {
        Export-ScanCSV
        Pause
```

- Calls your previously defined `Export-ScanCSV` function.
- Lets user manually pick a scan and download the CSV with serial-numbered filename.

### 🔴 Option 3: Exit + Kill Background Jobs

```powershell
"3" {
    $backgroundJobs = Get-Job -State "Running"
    if ($backgroundJobs.Count -gt 0) {
        foreach ($job in $backgroundJobs) {
            Stop-Job -Job $job
            Remove-Job -Job $job
...
else {
                Write-Host "`nNo background monitoring jobs are running."
```

- Gracefully exits the script.
- Before exiting, checks for **any running background jobs** (like the `Start-Monitoring` job).
- Stops and removes each job.
- Displays status per job.

Means:

> ✅ Check if $count is greater than 0
> 

Here:

- `$jobs.Count` → total number of running jobs.
- `gt 0` → means *"more than zero"* (i.e., **at least one job is running**).

**🧠 Real World Meaning:**

> "If the number of items is more than zero, do something."
>
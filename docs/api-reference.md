# Tenable.io API Reference

## Overview

The PowerShell implementation communicates with Tenable.io using REST API requests.

The API base URL used by the project is:

```text
https://cloud.tenable.com
```

Authentication is performed using the Tenable API key header:

```text
X-ApiKeys: accessKey=<ACCESS_KEY>; secretKey=<SECRET_KEY>
```

> Never document or commit real access keys or secret keys.

## 1. Retrieve Available Scans

```http
GET /scans
```

Purpose:

Retrieves the available scans so the operator can select a scan ID for automated monitoring or manual export.

PowerShell example:

```powershell
$scans = Invoke-RestMethod `
    -Method Get `
    -Uri "$TenableBaseUrl/scans" `
    -Headers $headers
```

## 2. Launch Scan

```http
POST /scans/{scanId}/launch
```

Purpose:

Starts the selected Tenable.io scan.

The response is expected to provide a scan UUID.

Example:

```powershell
$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$TenableBaseUrl/scans/$scanId/launch" `
    -Headers $headers
```

## 3. Get Scan Status

```http
GET /scans/{scanId}
```

Purpose:

Checks the current state of the selected scan.

The implementation reads the scan status from the response.

Example statuses handled by the original implementation include:

```text
completed
```

## 4. Request CSV Export

```http
POST /scans/{scanId}/export
```

Request body:

```json
{
  "format": "csv"
}
```

PowerShell example:

```powershell
$body = @{
    format = "csv"
} | ConvertTo-Json

$exportResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "$TenableBaseUrl/scans/$scanId/export" `
    -Headers $headers `
    -Body $body
```

## 5. Check Export Status

```http
GET /scans/{scanId}/export/{fileId}/status
```

Purpose:

Checks whether the requested CSV export is ready for download.

The implementation waits until the export status becomes:

```text
ready
```

## 6. Download Export

```http
GET /scans/{scanId}/export/{fileId}/download
```

Purpose:

Downloads the generated CSV report.

Example:

```powershell
Invoke-RestMethod `
    -Method Get `
    -Uri "$exportUrl/$fileId/download" `
    -Headers $headers `
    -OutFile $csvPath
```

## API Security

API credentials must be stored locally and never committed to Git.

Recommended configuration location:

```text
config/config.ps1
```

Repository-safe template:

```text
config/config.example.ps1
```

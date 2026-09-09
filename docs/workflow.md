# Workflow

## Automated Workflow

The application follows the workflow below:

```text
Microsoft Defender Event ID 1116
                ↓
        Read RecordId State
                ↓
       Identify New Event
                ↓
          Queue Scan
                ↓
       Launch Tenable Scan
                ↓
     Monitor Scan Status
                ↓
        Scan Completed
                ↓
       Request CSV Export
                ↓
      Wait for Export Ready
                ↓
         Download CSV
                ↓
      Store Local Report
```

## Initial Processing

During initial monitoring, the application reads the previously stored `LastRecordId`.

Defender Event ID `1116` entries with a greater `RecordId` are considered for processing.

The detected events are then placed into the scan workflow sequentially.

## Continuous Monitoring

After initial processing, the application periodically checks the Defender operational event log for new Event ID `1116` detections.

The monitoring cycle follows:

```text
Check Event Log
      ↓
Read latest Event ID 1116 entries
      ↓
Compare RecordId
      ↓
Process new events
      ↓
Queue scan requests
      ↓
Repeat
```

## Scan Processing

For each queued scan request:

```text
Queue Item
    ↓
Launch Scan
    ↓
Receive Scan UUID
    ↓
Poll Scan Status
    ↓
Wait for Completion
```

## CSV Export

After the scan reaches completion:

```text
Completed Scan
      ↓
POST Export Request
      ↓
Receive Export File ID
      ↓
Poll Export Status
      ↓
Status = Ready
      ↓
Download CSV
```

## Report Naming

Automated reports use:

```text
Auto_TenableReport_<ScanID>_<Serial>.csv
```

Example:

```text
Auto_TenableReport_1234_1.csv
Auto_TenableReport_1234_2.csv
```

Manual exports use:

```text
TenableReport_<ScanID>_<Serial>.csv
```

## Manual Export Workflow

The interactive menu supports independent report generation:

```text
Display Available Scans
        ↓
Select Scan ID
        ↓
Request CSV Export
        ↓
Wait for Readiness
        ↓
Download Report
        ↓
Store Locally
```

## Logging Workflow

Operational activity is recorded locally:

```text
Defender Detection
       ↓
DefenderLog.txt

Runtime / API Error
       ↓
ErrorLog.txt

Last Processed Event
       ↓
LastRecordId.txt
```

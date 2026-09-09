# Defender → Tenable Security Automation

Automated security-response workflow integrating **Microsoft Defender Event ID 1116 detection** with **Tenable.io vulnerability scanning and CSV reporting** using PowerShell.

The project monitors Defender threat-detection events, tracks processed events through `RecordId`, queues scan requests, launches a selected Tenable.io scan, waits for completion, and exports the resulting report as a CSV file.

---

## Overview

This project demonstrates how endpoint threat detection can be integrated with vulnerability-management tooling through API-based automation.

### Security Workflow

```text
Microsoft Defender Event ID 1116
              ↓
       RecordId Tracking
              ↓
         Scan Queue
              ↓
      Tenable.io API
        Scan Launch
              ↓
     Scan Status Monitoring
              ↓
       Scan Completion
              ↓
         CSV Export
              ↓
      Local Report Storage
```

The project also provides an interactive command-line menu for starting Defender monitoring and manually exporting a CSV report from a selected Tenable.io scan.

---

## Key Features

* 🛡️ Monitor Microsoft Defender Event ID `1116`
* 🔎 Detect previously unprocessed Defender events
* 🧾 Track Defender `RecordId` values
* 📦 Queue scan requests for sequential processing
* 🚀 Launch Tenable.io scans through the API
* ⏳ Monitor scan status until completion
* 📤 Automatically generate CSV reports
* 🗂️ Store reports locally with numbered filenames
* 🕐 Continuously monitor for new Defender events
* 📋 Manually export CSV reports for a selected scan
* 🖥️ Interactive command-line menu
* 📝 Defender and error logging
* 🛑 Background job cleanup during exit

---

## Project Scope

This project focuses on automating the **security-response lifecycle from endpoint threat detection to vulnerability assessment and report generation**.

The solution is designed to establish a controlled workflow between **Microsoft Defender** and **Tenable.io**, enabling detected security events to initiate a structured vulnerability-scanning process with minimal manual intervention.

### Scope of Automation

The automation covers the following end-to-end workflow:

```text
Endpoint Threat Detection
          ↓
Security Event Identification
          ↓
Event / RecordId Tracking
          ↓
Scan Request Scheduling
          ↓
Tenable.io Vulnerability Scan
          ↓
Scan Status Monitoring
          ↓
Report Generation & Export
          ↓
Local Report Storage
```

The project also provides an **interactive command-line interface** for operational control, including automated Defender monitoring and manual Tenable.io CSV report export.

### Repository Scope

The repository is structured as a GitHub-ready cybersecurity automation project, separating the implementation and supporting resources into dedicated areas for:

* PowerShell source code
* Configuration templates
* Technical documentation
* Testing resources
* Operational logs
* Generated reports
* Security guidance and project metadata

> **Repository Note:** This repository represents a structured organization of the supplied Markdown-based PowerShell project. The original implementation has not been functionally modified or runtime-tested as part of this structural conversion.


---

## Architecture

```text
┌───────────────────────────────────────────┐
│       Microsoft Windows Defender          │
│           Event ID 1116 Detection         │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│          RecordId Tracking                │
│   Track previously processed events       │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│              Scan Queue                   │
│       Sequential scan processing          │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│             Tenable.io API                │
│        Scan Launch & Monitoring            │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│           Scan Completion                 │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│            CSV Report Export              │
│        Generate → Ready → Download       │
└───────────────────────┬───────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────┐
│          Local Report Storage             │
│          Reports + Operational Logs       │
└───────────────────────────────────────────┘
```

---

## Operational Modes

### Automated Monitoring

The monitoring workflow:

```text
Defender Event 1116
        ↓
RecordId Validation
        ↓
Queue Scan Request
        ↓
Launch Tenable Scan
        ↓
Wait for Completion
        ↓
Export CSV
        ↓
Save Report
```

### Manual CSV Export

The interactive menu also allows an operator to:

```text
List Available Tenable Scans
        ↓
Select Scan ID
        ↓
Request CSV Export
        ↓
Wait for Export Readiness
        ↓
Download Report
        ↓
Save Locally
```

---

## Interactive Menu

The PowerShell application provides a simple command-line interface:

```text
==============================================
     Tenable Scanner Interactive Menu
==============================================

1. Monitor Windows Defender Event ID 1116
   and Trigger Scan

2. Export CSV Report from a Specific Scan

3. Exit Program

==============================================
```

---

## Technologies

| Technology              | Purpose                        |
| ----------------------- | ------------------------------ |
| PowerShell              | Automation and orchestration   |
| Microsoft Defender      | Threat detection               |
| Windows Event Log       | Security event collection      |
| Tenable.io              | Vulnerability scanning         |
| Tenable API             | Scan control and report export |
| CSV                     | Vulnerability scan reporting   |
| Windows Background Jobs | Continuous monitoring          |

---

## Prerequisites

Before running the project, ensure the following are available:

* Windows operating system
* Windows PowerShell
* Microsoft Defender
* Administrative privileges
* Tenable.io account
* Tenable.io API credentials
* A configured Tenable.io scan
* Network connectivity to Tenable.io

---

## Repository Structure

```text
defender-tenable-automation/
│
├── README.md
├── run-defender-tenable.bat
│
├── src/
│   └── defender-tenable-scanner.ps1
│
├── config/
│   ├── config.example.ps1
│   └── config.ps1
│
├── docs/
│   ├── architecture.md
│   ├── workflow.md
│   └── api-reference.md
│
├── diagrams/
│   └── .gitkeep
│
├── logs/
│   └── .gitkeep
│
├── reports/
│   └── .gitkeep
│
├── tests/
│   └── test-configuration.ps1
│
├── .gitignore
├── LICENSE
└── SECURITY.md
```

---

## Configuration

Copy the example configuration:

```powershell
Copy-Item .\config\config.example.ps1 .\config\config.ps1
```

Configure the required values inside:

```text
config/config.ps1
```

Typical configuration includes:

```text
Tenable API Access Key
Tenable API Secret Key
Tenable Base URL
Defender Event Log
Defender Event ID
Log Directory
Report Directory
Polling Intervals
Timeout Settings
```

### Security Requirement

Never commit real API credentials to Git.

`config/config.ps1` is intentionally excluded through `.gitignore`.

---

## Usage

### Start the PowerShell Application

From the repository root:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\src\defender-tenable-scanner.ps1"
```

The application starts the interactive menu.

---

## Windows Batch Launcher

A separate batch launcher is included for convenient execution.

### File

```text
run-defender-tenable.bat
```

### Script

```bat
@echo off
title Defender-Tenable Security Automation

powershell.exe -ExecutionPolicy Bypass -File "%~dp0src\defender-tenable-scanner.ps1"

pause
```

The `%~dp0` variable makes the PowerShell path relative to the location of the batch file instead of using a hard-coded user or desktop path.

For example, it avoids paths such as:

```text
C:\Users\Smart Security\Desktop\
```

---

## Output

Automated CSV reports follow the naming convention:

```text
Auto_TenableReport_<ScanID>_<Serial>.csv
```

Example:

```text
Auto_TenableReport_1234_1.csv
Auto_TenableReport_1234_2.csv
Auto_TenableReport_1234_3.csv
```

Manual exports use:

```text
TenableReport_<ScanID>_<Serial>.csv
```

Example:

```text
TenableReport_1234_1.csv
```

Reports should be stored under:

```text
reports/
```

Operational logs should be stored under:

```text
logs/
```

---

## Logging

The project maintains operational information related to:

* Defender Event ID 1116 detections
* Defender `RecordId` values
* Scan activity
* Report export activity
* Runtime and API errors

Example log files include:

```text
DefenderLog.txt
ErrorLog.txt
LastRecordId.txt
```

---

## Documentation

Detailed technical explanations are maintained separately from the main README.

| Document                | Description                                |
| ----------------------- | ------------------------------------------ |
| `docs/architecture.md`  | Technical architecture and components      |
| `docs/workflow.md`      | Detailed event-to-report workflow          |
| `docs/api-reference.md` | Tenable API operations used by the project |

This keeps the main README focused on project overview and usage while allowing deeper technical documentation to remain available for reference.

---

## Security Considerations

This project interacts with security telemetry and vulnerability-management systems.

Follow these practices:

* Never commit Tenable API access keys or secret keys.
* Keep `config/config.ps1` local.
* Do not commit production vulnerability reports.
* Do not commit confidential Defender logs.
* Do not expose client, bank, infrastructure, or host information.
* Use dedicated API credentials with appropriate privileges.
* Rotate credentials when required.
* Protect locally stored reports and logs.

> **Important:** Any API credentials accidentally committed to a public repository should be considered exposed and should be revoked or rotated immediately.

---

## Limitations

The current repository represents the supplied PowerShell implementation as a structured GitHub project.

The following are outside the scope of this structural conversion:

* Functional redesign
* Runtime testing
* Performance benchmarking
* Production deployment validation
* Tenable API behavior verification
* Enterprise-scale queue persistence
* Service-based deployment

---

## Future Improvements

Potential future enhancements include:

* Persistent queue storage
* Improved retry and timeout handling
* Structured JSON logging
* Centralized logging
* Windows Service deployment
* Better error recovery
* Metrics such as MTTD and MTTR
* SIEM/SOC integration
* Notification integration
* Enhanced configuration validation
* Automated testing and CI/CD

---

## Disclaimer

This project is intended for **authorized security monitoring, vulnerability-management, research, and educational environments**.

Only use the automation against systems, Tenable environments, and security infrastructure for which you have explicit authorization.

---

## License

This project is licensed under the MIT License.

See [`LICENSE`](LICENSE) for details.

---

## Author

**Abdullah Al Masum**

Cybersecurity / IT Audit / GRC

GitHub: [@abdullah-almasum](https://github.com/abdullah-almasum)

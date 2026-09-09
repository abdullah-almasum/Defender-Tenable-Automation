# Architecture

## Overview

The Defender → Tenable automation follows an event-driven security workflow that connects endpoint threat detection with vulnerability scanning and report generation.

## High-Level Architecture

```text
┌───────────────────────────────────────────────┐
│          Microsoft Windows Defender           │
│                                               │
│             Event ID 1116 Detection           │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│            RecordId Tracking Layer             │
│                                               │
│     Identifies previously processed events     │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│                 Scan Queue                    │
│                                               │
│       Sequential scan request processing      │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│                Tenable.io API                 │
│                                               │
│         Scan Launch & Status Monitoring       │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│              Report Generation                │
│                                               │
│       CSV Export → Readiness Check            │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│               Local Storage                   │
│                                               │
│             Reports + Logs                    │
└───────────────────────────────────────────────┘
```

## Components

### Microsoft Defender

Windows Defender provides the source security event. Event ID `1116` is used by the project as the trigger for the automated workflow.

### RecordId Tracking

The application records the last processed Defender event `RecordId`.

This provides basic state persistence so previously processed events can be identified during subsequent monitoring cycles.

### Scan Queue

Detected events are converted into scan requests and processed sequentially.

The queue is intended to prevent multiple scan requests from being executed simultaneously.

### Tenable.io API

The application communicates with Tenable.io through REST API calls to:

* Retrieve available scans
* Launch a selected scan
* Monitor scan status
* Request CSV export
* Check export readiness
* Download the generated report

### Reporting

After successful scan completion, the scan output is exported to CSV and stored locally.

## Operational Interface

The application also provides an interactive command-line menu:

```text
┌────────────────────────────────────────┐
│      Tenable Scanner Menu              │
├────────────────────────────────────────┤
│ 1. Defender Monitoring + Scan          │
│ 2. Manual CSV Export                  │
│ 3. Exit                               │
└────────────────────────────────────────┘
```

## Data Flow

```text
Security Event
      ↓
RecordId
      ↓
Queue
      ↓
Tenable Scan
      ↓
Completion
      ↓
CSV Export
      ↓
Local Report
```

## Security Boundary

The following data should remain outside the public repository:

* Tenable API credentials
* Production vulnerability reports
* Defender operational logs
* Client-specific information
* Internal hostnames and addresses
* Confidential security findings

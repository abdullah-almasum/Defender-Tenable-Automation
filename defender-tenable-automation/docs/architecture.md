## Architecture

The solution follows a simple event-driven security automation architecture:

```text
┌─────────────────────────────────────────────┐
│       Microsoft Windows Defender            │
│           Event ID 1116 Detection           │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│          RecordId Tracking & State          │
│     Identify and track processed events     │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│              Scan Queue                     │
│       Sequential scan request handling      │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│              Tenable.io API                 │
│            Scan Launch Request              │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│        Scan Status Monitoring               │
│       Wait until scan is completed          │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│             CSV Report Export               │
│       Generate → Check → Download           │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│            Local Report Storage             │
│       CSV Reports and Operational Logs      │
└─────────────────────────────────────────────┘

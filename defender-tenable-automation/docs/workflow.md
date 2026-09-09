## Workflow

This project implements an automated security-response workflow that connects Microsoft Defender threat detection with Tenable.io vulnerability scanning.

The overall workflow is:

**Microsoft Defender Event ID 1116**  
→ **RecordId Tracking**  
→ **Scan Queue Management**  
→ **Tenable.io API — Scan Launch**  
→ **Scan Status Monitoring**  
→ **Scan Completion**  
→ **CSV Report Export**  
→ **Local Report Storage**

In addition to the automated workflow, the project provides an **interactive command-line menu** that allows operators to start Defender monitoring, trigger automated scanning, and manually export CSV reports for a selected Tenable.io scan.

The RecordId tracking mechanism is used to identify previously processed Defender events and reduce duplicate processing.
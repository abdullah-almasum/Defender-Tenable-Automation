# API Reference

Endpoints used by the supplied implementation:

- `GET https://cloud.tenable.com/scans` — list scans
- `POST https://cloud.tenable.com/scans/{scanId}/launch` — launch a scan
- `GET https://cloud.tenable.com/scans/{scanId}` — poll scan status
- `POST https://cloud.tenable.com/scans/{scanId}/export` — request CSV export
- `GET https://cloud.tenable.com/scans/{scanId}/export/{fileId}/status` — poll export status
- `GET https://cloud.tenable.com/scans/{scanId}/export/{fileId}/download` — download CSV

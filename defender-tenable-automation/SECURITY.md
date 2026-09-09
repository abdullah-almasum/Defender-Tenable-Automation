# Security

- Never commit Tenable access or secret keys.
- Keep `config/config.ps1` local and ignored.
- Rotate/revoke any API credentials that were previously exposed.
- Do not commit production logs, scan reports, client data, IPs, or hostnames.
- If a secret is committed, revoke it immediately and remove it from Git history before republishing.

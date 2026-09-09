# Security Policy

## Security Overview

This project interacts with endpoint security telemetry and Tenable.io vulnerability-management services.

Because the application handles security-related data and API credentials, users should follow appropriate security controls when deploying or modifying the project.

## Credential Management

Never commit:

- Tenable API access keys
- Tenable API secret keys
- Passwords
- Tokens
- `.env` files
- Production credentials

Store local credentials in:

```text
config/config.ps1
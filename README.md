# Microsoft 365 & Entra ID Administration Lab

Hands-on lab simulating real MSP helpdesk and Level 2 tasks in a Microsoft 365 tenant.
Every task was completed in the admin portals, then **automated with PowerShell**
(Microsoft Graph SDK + Exchange Online), with a security review of each one.

## Skills demonstrated
- **Identity lifecycle** – onboarding, licensing, password reset, secure offboarding
- **Access control** – least-privilege admin roles (Global Reader, Authentication Administrator)
- **MFA** – enforcement, secure MFA reset, Temporary Access Pass
- **Groups** – security, Microsoft 365, distribution and dynamic groups
- **Exchange Online** – shared mailboxes, Full Access / Send As, aliases, forwarding, moderation
- **PowerShell automation** – idempotent scripts, `-WhatIf` support, audit snapshots

## Lab contents

| Folder | Topic | Status |
|--------|-------|--------|
| [01-user-lifecycle](01-user-lifecycle) | Create, license, reset, MFA, guest, offboard | ✅ |
| 02-roles-rbac | Admin role assignment, least privilege | 🔄 |
| 03-groups | Security, M365 and distribution groups | 🔄 |
| 04-dynamic-groups | Attribute-based membership rules | 🔄 |
| 05-exchange | Shared mailboxes, permissions, forwarding, moderation | 🔄 |
| 06-troubleshooting | OST vs PST, resource mailboxes, Outlook issues | 🔄 |

## Security considerations
- MFA resets require recorded identity verification (social-engineering risk)
- Offboarding revokes sessions, not just passwords
- External auto-forwarding is blocked by default (data exfiltration risk)
- No credentials, tenant names or IDs are stored in this repo

## Environment
Microsoft 365 lab tenant · Entra ID · Exchange Online · PowerShell 7 · Microsoft Graph PowerShell SDK

> ⚠️ For lab / learning use. Test with `-WhatIf` and never run against a production tenant without review.

## Author
**Sanjay Thapa** – IT Support, Sydney · working towards a SOC Analyst role
[LinkedIn](https://www.linkedin.com/in/your-profile)

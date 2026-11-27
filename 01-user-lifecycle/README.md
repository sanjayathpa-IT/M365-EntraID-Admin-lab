# 01 – User Lifecycle (Joiner · Mover · Leaver)

## Scenario
A small Australian business needs its helpdesk to handle the full life of a user account:
onboard new staff with licences and MFA, handle password and MFA resets, update
records when people change roles, give external people guest access, and offboard
leavers securely.

Each task was first completed in the **Microsoft 365 / Entra admin centre**, then
automated with **PowerShell (Microsoft Graph SDK)** so it is repeatable and auditable.

## Tasks covered

| # | Task | Script |
|---|------|--------|
| 1 | Create users Ram Adhikari and Shyam KC, assign licence, enforce MFA | [`New-LabUsers.ps1`](New-LabUsers.ps1) + [`users.csv`](users.csv) |
| 2 | Reset Ram's password – temporary password, must change at next sign-in | [`Reset-LabUserPassword.ps1`](Reset-LabUserPassword.ps1) |
| 3 | Update Ram's department to **IT** and job title to **Network Engineer** | [`Update-LabUserProfile.ps1`](Update-LabUserProfile.ps1) |
| 4 | Reset Shyam's MFA after he lost his phone | [`Reset-LabUserMfa.ps1`](Reset-LabUserMfa.ps1) |
| 5 | Block Ram, remove him from all groups and remove his licence | [`Remove-LabUserAccess.ps1`](Remove-LabUserAccess.ps1) |
| 6 | Create a guest user | [`New-LabGuestUser.ps1`](New-LabGuestUser.ps1) |

> Admin roles (Global Reader, Authentication Administrator) → [`02-roles-rbac`](../02-roles-rbac)
> Alias, forwarding and auto-reply → [`05-exchange`](../05-exchange)

## Prerequisites
- PowerShell 7+
- Microsoft Graph PowerShell SDK: `Install-Module Microsoft.Graph -Scope CurrentUser`
- A Microsoft 365 tenant with an admin account (lab/trial tenant, **never production**)

## How to run
```powershell
# 1. Connect (once per session)
.\Connect-Lab.ps1

# 2. Always preview first with -WhatIf
.\New-LabUsers.ps1 -CsvPath .\users.csv -Domain yourtenant.onmicrosoft.com -WhatIf

# 3. Run for real
.\New-LabUsers.ps1 -CsvPath .\users.csv -Domain yourtenant.onmicrosoft.com -SkuPartNumber SPB -EnforcePerUserMfa

.\Reset-LabUserPassword.ps1 -UserPrincipalName ram.adhikari@yourtenant.onmicrosoft.com
.\Update-LabUserProfile.ps1 -UserPrincipalName ram.adhikari@yourtenant.onmicrosoft.com -Department IT -JobTitle "Network Engineer"
.\Reset-LabUserMfa.ps1 -UserPrincipalName shyam.kc@yourtenant.onmicrosoft.com -VerificationNote "Manager confirmed via Teams call" -IssueTemporaryAccessPass
.\New-LabGuestUser.ps1 -Email guest@example.com -DisplayName "External Tester"
.\Remove-LabUserAccess.ps1 -UserPrincipalName ram.adhikari@yourtenant.onmicrosoft.com
```

## Results

<!-- Replace with your own screenshots (blur tenant name, emails and IDs) -->
| | |
|---|---|
| Users created and licensed | ![Users created](../screenshots/01-users-created.png) |
| Ram's updated job details | ![Profile updated](../screenshots/01-ram-profile-updated.png) |
| Shyam's MFA methods after reset | ![MFA reset](../screenshots/01-shyam-mfa-reset.png) |
| Ram offboarded: blocked, unlicensed, no groups | ![Offboarded](../screenshots/01-ram-offboarded.png) |
| Offboarding script output | ![Script output](../screenshots/01-offboard-script.png) |

## Security notes

**Temporary passwords** – Generated with a cryptographically secure random generator,
shown on screen once, never saved to disk, and must be changed at first sign-in.
They should be sent through a different channel from the username (e.g. SMS, phone).
Emailing a password to a personal Gmail works in a lab, but in production a
**Temporary Access Pass** is the safer option.

**MFA resets are a social-engineering target** – Attackers phone helpdesks pretending
to be a user who "lost their phone" (this was the initial access in the 2023 MGM Resorts
breach). The MFA reset script will not run without a `-VerificationNote` recording *how*
identity was verified, e.g. a call-back to a number from the HR system or confirmation
from the user's manager.

**Per-user MFA vs Conditional Access** – `-EnforcePerUserMfa` uses the legacy
per-user setting to match the lab task. Microsoft's recommended approach is a
**Conditional Access policy** requiring MFA for all users (or Security Defaults for
tenants without Entra ID P1). This is covered in the security baseline project.

**Offboarding order matters** – Disabling the account alone does not end existing
sessions; a stolen or still-signed-in device can keep working until its token expires.
The script blocks sign-in and **revokes sessions first**, then removes admin roles,
groups and licences. A JSON snapshot is saved before any change for audit and rollback.

**Mailbox data** – Removing the Exchange licence deletes the mailbox after 30 days.
If the mailbox is needed, convert it to a shared mailbox first (see section 05).

## What I learned
<!-- Write 3–5 points in your own words. Examples to think about:
- UsageLocation must be set before a licence can be assigned
- Difference between disabling an account and revoking sessions
- Why dynamic groups and group-based licences can't be removed directly
- Something that broke and how you fixed it -->

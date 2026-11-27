<#
.SYNOPSIS
    Resets a user's MFA after a lost or replaced phone, so they can register again.

.DESCRIPTION
    1. Records how the requester's identity was verified (mandatory - see Security notes)
    2. Removes Microsoft Authenticator, phone (SMS/call) and software OATH methods
    3. Revokes all sessions so any device still signed in has to re-authenticate
    4. Optionally issues a one-time Temporary Access Pass (TAP) so the user can
       sign in once and register their new phone

    MFA resets are a favourite social-engineering target: attackers ring the helpdesk
    pretending to be a user who "lost their phone". Never reset MFA without verifying
    identity through a channel the caller doesn't control.

.PARAMETER VerificationNote
    How identity was verified, e.g. "Manager Sita Sharma confirmed via Teams call".

.PARAMETER IssueTemporaryAccessPass
    Creates a 60-minute, single-use TAP. Requires the TAP policy to be enabled in
    Entra admin centre > Protection > Authentication methods > Temporary Access Pass.

.EXAMPLE
    .\Reset-LabUserMfa.ps1 -UserPrincipalName shyam.kc@contoso.onmicrosoft.com -VerificationNote "Called back on HR-listed number" -IssueTemporaryAccessPass
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users.Actions
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [Parameter(Mandatory)][ValidateLength(10, 500)][string]$VerificationNote,
    [switch]$IssueTemporaryAccessPass
)

$user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
Write-Host "Identity verification: $VerificationNote" -ForegroundColor Cyan

if (-not $PSCmdlet.ShouldProcess($UserPrincipalName, 'Remove all MFA methods and revoke sessions')) { return }

$removed = [System.Collections.Generic.List[string]]::new()

foreach ($m in Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.Id) {
    try {
        Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.Id -MicrosoftAuthenticatorAuthenticationMethodId $m.Id -ErrorAction Stop
        $removed.Add("Authenticator app ($($m.DisplayName))")
    } catch { Write-Warning "Could not remove Authenticator method: $($_.Exception.Message)" }
}

foreach ($m in Get-MgUserAuthenticationSoftwareOathMethod -UserId $user.Id) {
    try {
        Remove-MgUserAuthenticationSoftwareOathMethod -UserId $user.Id -SoftwareOathAuthenticationMethodId $m.Id -ErrorAction Stop
        $removed.Add('Software OATH token')
    } catch { Write-Warning "Could not remove OATH method: $($_.Exception.Message)" }
}

# Remove phone methods last - Entra may refuse to remove the default method while others exist
foreach ($m in Get-MgUserAuthenticationPhoneMethod -UserId $user.Id) {
    try {
        Remove-MgUserAuthenticationPhoneMethod -UserId $user.Id -PhoneAuthenticationMethodId $m.Id -ErrorAction Stop
        $removed.Add("Phone ($($m.PhoneType))")
    } catch { Write-Warning "Could not remove phone method: $($_.Exception.Message)" }
}

Revoke-MgUserSignInSession -UserId $user.Id -ErrorAction Stop | Out-Null

Write-Host "MFA reset for $($user.DisplayName)" -ForegroundColor Green
if ($removed.Count) { $removed | ForEach-Object { Write-Host "  removed: $_" } }
else { Write-Host '  no MFA methods were registered' }
Write-Host '  all sessions revoked'

if ($IssueTemporaryAccessPass) {
    $tap = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -BodyParameter @{
        lifetimeInMinutes = 60
        isUsableOnce      = $true
    } -ErrorAction Stop
    Write-Host "Temporary Access Pass (single use, 60 min): $($tap.TemporaryAccessPass)" -ForegroundColor Yellow
    Write-Host 'User signs in at https://aka.ms/mysecurityinfo with the TAP and registers the new phone.'
}
else {
    Write-Host 'At next sign-in the user will be prompted to register MFA again.'
}

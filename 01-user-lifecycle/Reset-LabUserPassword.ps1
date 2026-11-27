<#
.SYNOPSIS
    Resets a user's password to a random temporary one that must be changed at next sign-in.

.PARAMETER UserPrincipalName
    The user to reset, e.g. ram.adhikari@contoso.onmicrosoft.com

.PARAMETER RevokeSessions
    Also signs the user out of all existing sessions. Use this when the password
    may be compromised.

.EXAMPLE
    .\Reset-LabUserPassword.ps1 -UserPrincipalName ram.adhikari@contoso.onmicrosoft.com -RevokeSessions
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Users.Actions
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [switch]$RevokeSessions
)

function New-TempPassword {
    param([int]$Length = 16)
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%^&*?')
    $all  = -join $sets
    $rng  = [System.Security.Cryptography.RandomNumberGenerator]
    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($set in $sets) { $chars.Add($set[$rng::GetInt32($set.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[$rng::GetInt32($all.Length)]) }
    -join ($chars | Sort-Object { $rng::GetInt32([int]::MaxValue) })
}

$user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop

if ($PSCmdlet.ShouldProcess($UserPrincipalName, 'Reset password')) {
    $tempPassword = New-TempPassword
    Update-MgUser -UserId $user.Id -PasswordProfile @{
        Password                      = $tempPassword
        ForceChangePasswordNextSignIn = $true
    } -ErrorAction Stop

    if ($RevokeSessions) {
        Revoke-MgUserSignInSession -UserId $user.Id -ErrorAction Stop | Out-Null
        Write-Host 'All existing sessions revoked.' -ForegroundColor Cyan
    }

    Write-Host "Password reset for $($user.DisplayName)." -ForegroundColor Green
    Write-Host "Temporary password: $tempPassword"
    Write-Host 'User must change it at next sign-in. Send it through a separate channel from the username (e.g. SMS or phone call).' -ForegroundColor Yellow
}

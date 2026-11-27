<#
.SYNOPSIS
    Bulk-creates Microsoft 365 users from a CSV, assigns a licence and can enforce per-user MFA.

.DESCRIPTION
    For each row in the CSV the script:
      1. Skips the user if the UPN already exists (safe to re-run)
      2. Creates the account with a random temporary password (must change at first sign-in)
      3. Sets UsageLocation (required before any licence can be assigned)
      4. Assigns the chosen licence
      5. Optionally enforces per-user MFA (-EnforcePerUserMfa)

    Temporary passwords are shown on screen ONCE and are never written to disk.

.PARAMETER CsvPath
    CSV with columns: FirstName, LastName, UserName, Department, JobTitle, State, Country, UsageLocation

.PARAMETER Domain
    Tenant domain, e.g. contoso.onmicrosoft.com

.PARAMETER SkuPartNumber
    Licence to assign. Common values: SPB (Business Premium), O365_BUSINESS_ESSENTIALS (Business Basic),
    DEVELOPERPACK_E5 (E5 developer). Run Get-MgSubscribedSku to see yours.

.PARAMETER EnforcePerUserMfa
    Sets legacy per-user MFA to "enforced". Conditional Access is the recommended approach -
    see README.

.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv -Domain contoso.onmicrosoft.com -WhatIf

.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv -Domain contoso.onmicrosoft.com -SkuPartNumber SPB -EnforcePerUserMfa
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Users.Actions, Microsoft.Graph.Identity.DirectoryManagement
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$CsvPath,
    [Parameter(Mandatory)][string]$Domain,
    [string]$SkuPartNumber = 'SPB',
    [switch]$EnforcePerUserMfa
)

function New-TempPassword {
    # Cryptographically secure random password with upper, lower, digit and symbol.
    param([int]$Length = 16)
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%^&*?')
    $all  = -join $sets
    $rng  = [System.Security.Cryptography.RandomNumberGenerator]
    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($set in $sets) { $chars.Add($set[$rng::GetInt32($set.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[$rng::GetInt32($all.Length)]) }
    -join ($chars | Sort-Object { $rng::GetInt32([int]::MaxValue) })
}

# --- Licence check -----------------------------------------------------------
$sku = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $SkuPartNumber
if (-not $sku) {
    $available = (Get-MgSubscribedSku -All).SkuPartNumber -join ', '
    throw "Licence '$SkuPartNumber' not found in this tenant. Available: $available"
}
$freeLicences = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
Write-Host "Licence $SkuPartNumber - $freeLicences available" -ForegroundColor Cyan

# --- Create users ------------------------------------------------------------
$rows    = Import-Csv -Path $CsvPath
$results = [System.Collections.Generic.List[object]]::new()

foreach ($row in $rows) {
    $upn = "$($row.UserName)@$Domain"

    if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
        Write-Warning "$upn already exists - skipping"
        $results.Add([pscustomobject]@{ User = $upn; Status = 'Skipped (exists)'; TempPassword = '-' })
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($upn, 'Create user and assign licence')) { continue }

    $tempPassword = New-TempPassword
    $params = @{
        AccountEnabled    = $true
        DisplayName       = "$($row.FirstName) $($row.LastName)"
        GivenName         = $row.FirstName
        Surname           = $row.LastName
        UserPrincipalName = $upn
        MailNickname      = $row.UserName
        UsageLocation     = $row.UsageLocation
        Department        = $row.Department
        JobTitle          = $row.JobTitle
        State             = $row.State
        Country           = $row.Country
        PasswordProfile   = @{ Password = $tempPassword; ForceChangePasswordNextSignIn = $true }
    }
    # Graph rejects empty strings, so drop any blank CSV fields
    foreach ($key in @($params.Keys)) {
        if ([string]::IsNullOrWhiteSpace([string]$params[$key])) { $params.Remove($key) }
    }

    try {
        $newUser = New-MgUser @params -ErrorAction Stop
        $status  = 'Created'

        if ($freeLicences -gt 0) {
            Set-MgUserLicense -UserId $newUser.Id -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @() -ErrorAction Stop | Out-Null
            $freeLicences--
            $status += ', licensed'
        }
        else {
            Write-Warning "No free $SkuPartNumber licences - $upn created without a licence"
        }

        if ($EnforcePerUserMfa) {
            Invoke-MgGraphRequest -Method PATCH `
                -Uri "https://graph.microsoft.com/beta/users/$($newUser.Id)/authentication/requirements" `
                -Body @{ perUserMfaState = 'enforced' } -ErrorAction Stop
            $status += ', MFA enforced'
        }

        $results.Add([pscustomobject]@{ User = $upn; Status = $status; TempPassword = $tempPassword })
    }
    catch {
        Write-Error "Failed on ${upn}: $($_.Exception.Message)"
        $results.Add([pscustomobject]@{ User = $upn; Status = "FAILED: $($_.Exception.Message)"; TempPassword = '-' })
    }
}

$results | Format-Table -AutoSize
Write-Host 'Temporary passwords are shown once only. Deliver them through a separate secure channel - never store them in this repo.' -ForegroundColor Yellow

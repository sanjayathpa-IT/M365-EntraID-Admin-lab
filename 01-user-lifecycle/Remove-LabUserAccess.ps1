<#
.SYNOPSIS
    Offboards a user: blocks sign-in, revokes sessions, removes groups, admin roles and licences.

.DESCRIPTION
    Steps run in order of urgency - cut off access first, then clean up:
      1. Export a snapshot (groups, roles, licences) to ..\logs\ for audit / rollback
      2. Block sign-in
      3. Revoke all refresh tokens and sessions
      4. Remove admin role assignments
      5. Remove from security and Microsoft 365 groups
         (dynamic groups are skipped - they update automatically;
          distribution lists are flagged for Exchange - see section 05)
      6. Remove directly-assigned licences (group-assigned licences are flagged)

    WARNING: removing the Exchange licence deletes the mailbox after 30 days.
    If the mailbox must be kept, convert it to a shared mailbox first (section 05)
    or run with -KeepLicences.

.EXAMPLE
    .\Remove-LabUserAccess.ps1 -UserPrincipalName ram.adhikari@contoso.onmicrosoft.com -WhatIf

.EXAMPLE
    .\Remove-LabUserAccess.ps1 -UserPrincipalName ram.adhikari@contoso.onmicrosoft.com
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users.Actions
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [string]$LogFolder = (Join-Path $PSScriptRoot '..\logs'),
    [switch]$KeepLicences
)

$user = Get-MgUser -UserId $UserPrincipalName -Property Id, DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses, LicenseAssignmentStates -ErrorAction Stop
$summary = [System.Collections.Generic.List[string]]::new()

# --- 1. Snapshot -------------------------------------------------------------
$memberOf    = Get-MgUserMemberOf -UserId $user.Id -All
$groups      = $memberOf | Where-Object { $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group' }
$assignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($user.Id)'" -All

$snapshot = [ordered]@{
    User      = $user.UserPrincipalName
    TakenAt   = (Get-Date).ToString('s')
    Groups    = @($groups | ForEach-Object { $_.AdditionalProperties['displayName'] })
    RoleIds   = @($assignments.RoleDefinitionId)
    Licences  = @($user.AssignedLicenses.SkuId)
}
New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
$snapshotFile = Join-Path $LogFolder ("offboard-{0}-{1:yyyyMMdd-HHmm}.json" -f $user.UserPrincipalName.Split('@')[0], (Get-Date))
$snapshot | ConvertTo-Json -Depth 3 | Set-Content -Path $snapshotFile
$summary.Add("Snapshot saved to $snapshotFile")

if (-not $PSCmdlet.ShouldProcess($user.UserPrincipalName, 'Offboard user')) { return }

# --- 2 & 3. Cut off access ---------------------------------------------------
Update-MgUser -UserId $user.Id -AccountEnabled:$false -ErrorAction Stop
$summary.Add('Sign-in blocked')

Revoke-MgUserSignInSession -UserId $user.Id -ErrorAction Stop | Out-Null
$summary.Add('All sessions revoked')

# --- 4. Admin roles ----------------------------------------------------------
foreach ($a in $assignments) {
    $roleName = (Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $a.RoleDefinitionId).DisplayName
    try {
        Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $a.Id -ErrorAction Stop
        $summary.Add("Removed role: $roleName")
    } catch { Write-Warning "Could not remove role ${roleName}: $($_.Exception.Message)" }
}

# --- 5. Groups ---------------------------------------------------------------
foreach ($g in $groups) {
    $name       = $g.AdditionalProperties['displayName']
    $groupTypes = @($g.AdditionalProperties['groupTypes'])
    $mailOnly   = $g.AdditionalProperties['mailEnabled'] -and ($groupTypes -notcontains 'Unified')

    if ($groupTypes -contains 'DynamicMembership') {
        $summary.Add("Skipped dynamic group: $name (membership updates automatically)")
    }
    elseif ($mailOnly) {
        $summary.Add("ACTION NEEDED - distribution / mail-enabled security group: $name (remove with Remove-DistributionGroupMember in Exchange Online)")
    }
    else {
        try {
            Remove-MgGroupMemberDirectoryObjectByRef -GroupId $g.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            $summary.Add("Removed from group: $name")
        } catch { Write-Warning "Could not remove from ${name}: $($_.Exception.Message)" }
    }
}

# --- 6. Licences -------------------------------------------------------------
if ($KeepLicences) {
    $summary.Add('Licences kept (-KeepLicences)')
}
else {
    $direct  = @($user.LicenseAssignmentStates | Where-Object { -not $_.AssignedByGroup } | ForEach-Object SkuId | Select-Object -Unique)
    $viaGroup = @($user.LicenseAssignmentStates | Where-Object { $_.AssignedByGroup })

    if ($direct.Count) {
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses $direct -ErrorAction Stop | Out-Null
        $summary.Add("Removed $($direct.Count) direct licence(s)")
    }
    if ($viaGroup.Count) {
        $summary.Add('ACTION NEEDED - some licences are group-assigned; they drop off once the user leaves that group')
    }
}

Write-Host "`nOffboarding summary for $($user.DisplayName)" -ForegroundColor Green
$summary | ForEach-Object { Write-Host "  - $_" }

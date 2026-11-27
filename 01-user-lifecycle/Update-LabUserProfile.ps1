<#
.SYNOPSIS
    Updates a user's job details (department, job title, state, country) and shows before/after.

.DESCRIPTION
    These attributes matter beyond the address book: dynamic groups in section 04 use
    department, state and country to decide membership automatically.

.EXAMPLE
    .\Update-LabUserProfile.ps1 -UserPrincipalName ram.adhikari@contoso.onmicrosoft.com -Department IT -JobTitle "Network Engineer"
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Users
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [string]$Department,
    [string]$JobTitle,
    [string]$State,
    [string]$Country
)

$props = 'Id', 'DisplayName', 'Department', 'JobTitle', 'State', 'Country'
$before = Get-MgUser -UserId $UserPrincipalName -Property $props -ErrorAction Stop

$changes = @{}
foreach ($name in 'Department', 'JobTitle', 'State', 'Country') {
    if ($PSBoundParameters.ContainsKey($name)) { $changes[$name] = $PSBoundParameters[$name] }
}
if ($changes.Count -eq 0) { throw 'Nothing to update - pass at least one of -Department, -JobTitle, -State, -Country.' }

if ($PSCmdlet.ShouldProcess($UserPrincipalName, "Update $($changes.Keys -join ', ')")) {
    Update-MgUser -UserId $before.Id @changes -ErrorAction Stop
    $after = Get-MgUser -UserId $before.Id -Property $props

    foreach ($name in $changes.Keys) {
        [pscustomobject]@{ Attribute = $name; Before = $before.$name; After = $after.$name }
    }
}

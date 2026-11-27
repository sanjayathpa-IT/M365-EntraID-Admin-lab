<#
.SYNOPSIS
    Connects to Microsoft Graph with the permissions the user lifecycle scripts need.

.DESCRIPTION
    Run this once per PowerShell session before any other script in this folder.
    You will be asked to sign in with an admin account and consent to the scopes.

    Sign-in uses the browser instead of the Windows Web Account Manager (WAM) popup.
    WAM can wrongly treat a work account as a personal Microsoft account and fail
    with "That Microsoft account doesn't exist" - common on brand-new tenants.

.PARAMETER TenantId
    Tenant domain or ID, e.g. contoso.onmicrosoft.com. Targets the right tenant directly.

.EXAMPLE
    .\Connect-Lab.ps1 -TenantId contoso.onmicrosoft.com
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId
)

# Use browser sign-in rather than the WAM popup (see description)
Set-MgGraphOption -DisableLoginByWAM $true

$scopes = @(
    'User.ReadWrite.All'                       # create / update / disable users
    'User-PasswordProfile.ReadWrite.All'       # reset another user's password (not covered by User.ReadWrite.All)
    'Group.ReadWrite.All'                      # remove users from groups
    'Directory.ReadWrite.All'                  # licences and directory objects
    'RoleManagement.ReadWrite.Directory'       # remove admin role assignments
    'UserAuthenticationMethod.ReadWrite.All'   # reset MFA, Temporary Access Pass
    'Policy.ReadWrite.AuthenticationMethod'    # per-user MFA state
    'User.Invite.All'                          # invite guest users
    'Organization.Read.All'                    # read licence (SKU) information
)

Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome -ErrorAction Stop

$ctx = Get-MgContext
Write-Host "Connected to Microsoft Graph as $($ctx.Account)" -ForegroundColor Green

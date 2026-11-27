<#
.SYNOPSIS
    Connects to Microsoft Graph with the permissions the user lifecycle scripts need.

.DESCRIPTION
    Run this once per PowerShell session before any other script in this folder.
    You will be asked to sign in with an admin account and consent to the scopes.

.EXAMPLE
    .\Connect-Lab.ps1
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication
[CmdletBinding()]
param()

$scopes = @(
    'User.ReadWrite.All'                       # create / update / disable users
    'Group.ReadWrite.All'                      # remove users from groups
    'Directory.ReadWrite.All'                  # licences and directory objects
    'RoleManagement.ReadWrite.Directory'       # remove admin role assignments
    'UserAuthenticationMethod.ReadWrite.All'   # reset MFA, Temporary Access Pass
    'Policy.ReadWrite.AuthenticationMethod'    # per-user MFA state
    'User.Invite.All'                          # invite guest users
    'Organization.Read.All'                    # read licence (SKU) information
)

Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop

$ctx = Get-MgContext
Write-Host "Connected to Microsoft Graph as $($ctx.Account)" -ForegroundColor Green

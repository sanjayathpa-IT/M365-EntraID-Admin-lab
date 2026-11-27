<#
.SYNOPSIS
    Invites an external person as a B2B guest user.

.EXAMPLE
    .\New-LabGuestUser.ps1 -Email someone@gmail.com -DisplayName "External Tester" -SendInvite
#>
#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Identity.SignIns
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')][string]$Email,
    [Parameter(Mandatory)][string]$DisplayName,
    [switch]$SendInvite
)

if ($PSCmdlet.ShouldProcess($Email, 'Invite guest user')) {
    $invite = New-MgInvitation -InvitedUserEmailAddress $Email `
        -InvitedUserDisplayName $DisplayName `
        -InviteRedirectUrl 'https://myapplications.microsoft.com' `
        -SendInvitationMessage:$SendInvite.IsPresent -ErrorAction Stop

    [pscustomobject]@{
        Guest      = $DisplayName
        Email      = $Email
        UserId     = $invite.InvitedUser.Id
        Status     = $invite.Status
        InviteSent = $SendInvite.IsPresent
    }
    if (-not $SendInvite) { Write-Host "Redemption link (share securely): $($invite.InviteRedeemUrl)" -ForegroundColor Yellow }
}

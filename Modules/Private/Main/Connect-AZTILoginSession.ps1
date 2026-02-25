<#
.Synopsis
    Azure Login Session Module for Azure Scout

.DESCRIPTION
    Authenticates to Azure using one of five methods (in priority order):
      1. Managed Identity  — triggered by -Automation flag (handled in Invoke-AzureScout)
      2. SPN + Certificate — -AppId, -CertificatePath, -CertificatePassword
      3. SPN + Secret      — -AppId, -Secret
      4. Device Code        — -DeviceLogin switch
      5. Current User       — default; reuses existing Az context or prompts interactive login

    Single-tenant per run. TenantID is required for SPN auth and strongly recommended
    for all other methods.

.PARAMETER AzureEnvironment
    Azure cloud environment. Default: AzureCloud.

.PARAMETER TenantID
    Target Azure AD tenant ID. Required for SPN methods; optional for interactive.

.PARAMETER DeviceLogin
    Use device-code authentication flow.

.PARAMETER AppId
    Application (client) ID for service principal authentication.

.PARAMETER Secret
    Client secret for SPN + Secret auth. Requires -AppId and -TenantID.

.PARAMETER CertificatePath
    Path to PKCS#12 certificate file for SPN + Certificate auth.

.PARAMETER CertificatePassword
    Password protecting the certificate file. Passed as SecureString internally.

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
    Version: 1.0.0
    Authors: Claudio Merola, thisismydemo
#>
function Connect-AZSCLoginSession {
    [CmdletBinding()]
    param(
        [ValidateSet('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud', 'AzureGermanCloud')]
        [string]$AzureEnvironment = 'AzureCloud',

        [string]$TenantID,

        [switch]$DeviceLogin,

        [string]$AppId,

        [string]$Secret,

        [string]$CertificatePath,

        [string]$CertificatePassword
    )

    $ErrorActionPreference = 'Stop'

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Starting Connect-AZSCLoginSession')

    # -----------------------------------------------------------
    # Priority 2: SPN + Certificate
    # -----------------------------------------------------------
    if ($AppId -and $CertificatePath) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Auth method: SPN + Certificate')
        if (-not $TenantID) {
            throw 'TenantID is required for service principal authentication with certificate.'
        }

        $connectParams = @{
            ServicePrincipal = $true
            TenantId         = $TenantID
            ApplicationId    = $AppId
            CertificatePath  = $CertificatePath
            Environment      = $AzureEnvironment
        }
        if ($CertificatePassword) {
            $connectParams['CertificatePassword'] = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
        }

        Connect-AzAccount @connectParams | Out-Null
        Write-Host 'Authenticated via SPN + Certificate' -ForegroundColor Green
        return $TenantID
    }

    # -----------------------------------------------------------
    # Priority 3: SPN + Secret
    # -----------------------------------------------------------
    if ($AppId -and $Secret) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Auth method: SPN + Secret')
        if (-not $TenantID) {
            throw 'TenantID is required for service principal authentication with secret.'
        }

        $secureSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force
        $credential   = [System.Management.Automation.PSCredential]::new($AppId, $secureSecret)

        Connect-AzAccount -ServicePrincipal -TenantId $TenantID -Credential $credential -Environment $AzureEnvironment | Out-Null
        Write-Host 'Authenticated via SPN + Secret' -ForegroundColor Green
        return $TenantID
    }

    # -----------------------------------------------------------
    # Priority 4: Device Code
    # -----------------------------------------------------------
    if ($DeviceLogin.IsPresent) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Auth method: Device Code')

        $deviceParams = @{
            UseDeviceAuthentication = $true
            Environment             = $AzureEnvironment
        }
        if ($TenantID) { $deviceParams['Tenant'] = $TenantID }

        Connect-AzAccount @deviceParams | Out-Null
        Write-Host 'Authenticated via Device Code' -ForegroundColor Green

        if (-not $TenantID) {
            $TenantID = (Get-AzContext).Tenant.Id
        }
        return $TenantID
    }

    # -----------------------------------------------------------
    # Priority 5: Current User (default)
    # -----------------------------------------------------------
    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Auth method: Current User (default)')

    $context = Get-AzContext -ErrorAction SilentlyContinue

    # If we have a valid context matching the target tenant, reuse it
    if ($context -and $context.Account -and (-not $TenantID -or $context.Tenant.Id -eq $TenantID)) {
        $TenantID = $context.Tenant.Id
        Write-Host "Using existing Az context for tenant $TenantID" -ForegroundColor Green
        return $TenantID
    }

    # Need to authenticate interactively
    Write-Host 'No valid Az context found — launching interactive login...' -ForegroundColor Yellow

    $interactiveParams = @{ Environment = $AzureEnvironment }
    if ($TenantID) { $interactiveParams['Tenant'] = $TenantID }

    # Temporarily disable LoginExperienceV2 if enabled (avoids subscription picker)
    try {
        $loginConfig = Get-AzConfig -LoginExperienceV2 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
        if ($loginConfig.Value -eq 'On') {
            Update-AzConfig -LoginExperienceV2 Off | Out-Null
            Connect-AzAccount @interactiveParams | Out-Null
            Update-AzConfig -LoginExperienceV2 On | Out-Null
        }
        else {
            Connect-AzAccount @interactiveParams | Out-Null
        }
    }
    catch {
        Connect-AzAccount @interactiveParams | Out-Null
    }

    if (-not $TenantID) {
        $TenantID = (Get-AzContext).Tenant.Id
    }

    Write-Host "Authenticated interactively for tenant $TenantID" -ForegroundColor Green
    return $TenantID
}

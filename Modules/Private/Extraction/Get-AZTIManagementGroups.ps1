<#
.Synopsis
Module responsible for retrieving Azure Management Groups.

.DESCRIPTION
This module retrieves Azure Management Groups and their associated subscriptions.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/1.ExtractionFunctions/Get-AZSCManagementGroups.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC).

.NOTES
Version: 3.6.11
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>
function Get-AZSCManagementGroups {
    Param ($ManagementGroup,$Subscriptions)

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Management group name: ' + $ManagementGroup)

    $GraphQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions' | mv-expand managementGroupParent = properties.managementGroupAncestorsChain | where managementGroupParent.name =~ '$($ManagementGroup)'"

    # Page through the full result set via SkipToken — an unpaged -first 1000 call
    # silently drops every subscription past 1000 in a large management group (AB#5076).
    $LocalResults = @()
    $QueryResult = Search-AzGraph -Query $GraphQuery -first 1000 -Debug:$false
    $LocalResults += $QueryResult
    while ($QueryResult.SkipToken) {
        $QueryResult = Search-AzGraph -Query $GraphQuery -first 1000 -SkipToken $QueryResult.SkipToken -Debug:$false
        $LocalResults += $QueryResult
    }

    if ($LocalResults.Count -lt 1) {
        # Throw a terminating error rather than Exit, which would kill the whole
        # host / automation runbook uncatchably (AB#5077).
        throw "No Subscriptions found for Management Group: '$ManagementGroup'. Verify the management group name and try again."
    }
    else {
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Subscriptions found for Management Group: ' + $LocalResults.Count)
        $FinalSubscriptions = foreach ($Sub in $Subscriptions)
            {
                if ($Sub.name -in $LocalResults.name)
                    {
                        $Sub
                    }
            }
    }
    return $FinalSubscriptions
}
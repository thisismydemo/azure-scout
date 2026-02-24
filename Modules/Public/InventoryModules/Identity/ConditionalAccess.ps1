<#
.Synopsis
Inventory for Entra ID Conditional Access Policies

.DESCRIPTION
This script consolidates information for all entra/conditionalaccesspolicies resources.
Excel Sheet Name: Conditional Access

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/ConditionalAccess.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: AzureTenantInventory Contributors
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraCAPolicies = $Resources | Where-Object { $_.TYPE -eq 'entra/conditionalaccesspolicies' }

    if ($entraCAPolicies)
    {
        $tmp = foreach ($1 in $entraCAPolicies) {
            $ResUCount = 1
            $data = $1.properties

            # Users included/excluded
            $usersIncluded = ''
            $usersExcluded = ''
            if ($data.conditions.users) {
                if ($data.conditions.users.includeUsers) {
                    $usersIncluded = ($data.conditions.users.includeUsers -join ', ')
                }
                if ($data.conditions.users.excludeUsers) {
                    $usersExcluded = ($data.conditions.users.excludeUsers -join ', ')
                }
            }

            # Applications
            $appsIncluded = ''
            if ($data.conditions.applications) {
                if ($data.conditions.applications.includeApplications) {
                    $appsIncluded = ($data.conditions.applications.includeApplications -join ', ')
                }
            }

            # Grant controls
            $grantControls = ''
            if ($data.grantControls) {
                if ($data.grantControls.builtInControls) {
                    $grantControls = ($data.grantControls.builtInControls -join ', ')
                }
            }

            # Session controls
            $sessionControls = ''
            if ($data.sessionControls) {
                $scParts = @()
                if ($data.sessionControls.signInFrequency) { $scParts += 'SignInFrequency' }
                if ($data.sessionControls.persistentBrowser) { $scParts += 'PersistentBrowser' }
                if ($data.sessionControls.cloudAppSecurity) { $scParts += 'CloudAppSecurity' }
                if ($data.sessionControls.applicationEnforcedRestrictions) { $scParts += 'AppEnforcedRestrictions' }
                $sessionControls = ($scParts -join ', ')
            }

            $obj = @{
                'ID'                  = $1.id;
                'Tenant ID'           = $1.tenantId;
                'Display Name'        = $data.displayName;
                'State'               = $data.state;
                'Users Included'      = $usersIncluded;
                'Users Excluded'      = $usersExcluded;
                'Apps Included'       = $appsIncluded;
                'Grant Controls'      = $grantControls;
                'Session Controls'    = $sessionControls;
                'Created DateTime'    = $data.createdDateTime;
                'Modified DateTime'   = $data.modifiedDateTime;
                'Resource U'          = $ResUCount
            }
            $obj
            if ($ResUCount -eq 1) { $ResUCount = 0 }
        }
        $tmp
    }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    if ($SmaResources)
    {
        $TableName = ('CATable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText disabled -Range D:D
        $condtxt += New-ConditionalText enabledForReportingButNotEnforced -Range D:D

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('State')
        $Exc.Add('Users Included')
        $Exc.Add('Users Excluded')
        $Exc.Add('Apps Included')
        $Exc.Add('Grant Controls')
        $Exc.Add('Session Controls')
        $Exc.Add('Created DateTime')
        $Exc.Add('Modified DateTime')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Conditional Access' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}

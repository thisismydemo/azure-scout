<#
.Synopsis
Inventory for Azure Lighthouse Delegations

.DESCRIPTION
This script consolidates information for all Azure Lighthouse delegations.
Captures service provider access, delegated permissions, and managed tenant relationships.
Excel Sheet Name: Lighthouse Delegations

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/LighthouseDelegations.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Management

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $lighthouseDelegations = $Resources | Where-Object {$_.TYPE -eq 'Microsoft.ManagedServices/registrationDefinitions'}

    <######### Insert the resource Process here ########>

    if($lighthouseDelegations)
        {
            $tmp = foreach ($1 in $lighthouseDelegations) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Get registration details
                $registrationId = if ($data.registrationId) { $data.registrationId } else { 'N/A' }
                $description = if ($data.description) { $data.description } else { 'N/A' }

                # Get managing tenant
                $managedByTenantId = if ($data.managedByTenantId) { $data.managedByTenantId } else { 'N/A' }
                $managedByTenantName = if ($data.managedByTenantName) { $data.managedByTenantName } else { 'N/A' }

                # Parse authorizations (delegated permissions)
                $authorizations = @()
                if ($data.authorizations) {
                    foreach ($auth in $data.authorizations) {
                        $principalId = $auth.principalId
                        $principalIdDisplayName = if ($auth.principalIdDisplayName) {
                            $auth.principalIdDisplayName
                        } else { $principalId }
                        $roleDefinitionId = ($auth.roleDefinitionId -split '/')[-1]

                        # Map common role definition GUIDs to friendly names
                        $roleName = switch ($roleDefinitionId) {
                            'b24988ac-6180-42a0-ab88-20f7382dd24c' { 'Contributor' }
                            '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' { 'Owner' }
                            'acdd72a7-3385-48ef-bd42-f606fba81ae7' { 'Reader' }
                            '749f88d5-cbae-40b8-bcfc-e573ddc772fa' { 'Monitoring Contributor' }
                            '43d0d8ad-25c7-4714-9337-8ba259a9fe05' { 'Monitoring Reader' }
                            '92aaf0da-9dab-42b6-94a3-d43ce8d16293' { 'Log Analytics Contributor' }
                            default { $roleDefinitionId }
                        }

                        $delegationType = if ($auth.delegatedRoleDefinitionIds) {
                            'Eligible (JIT)'
                        } else { 'Permanent' }

                        $authorizations += "$principalIdDisplayName -> $roleName ($delegationType)"
                    }
                }
                $authStr = if ($authorizations.Count -gt 0) { $authorizations -join '; ' } else { 'None' }

                # Get provisioning state
                $provisioningState = if ($data.provisioningState) { $data.provisioningState } else { 'Unknown' }

                # Check eligibility authorizations
                $eligibleAuthCount = 0
                if ($data.eligibleAuthorizations) {
                    $eligibleAuthCount = $data.eligibleAuthorizations.Count
                }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Registration Name'         = $1.NAME;
                        'Description'               = $description;
                        'Registration ID'           = $registrationId;
                        'Managed By Tenant ID'      = $managedByTenantId;
                        'Managed By Tenant Name'    = $managedByTenantName;
                        'Authorizations'            = $authStr;
                        'Authorization Count'       = $authorizations.Count;
                        'Eligible Authorizations'   = $eligibleAuthCount;
                        'Provisioning State'        = $provisioningState;
                        'Resource U'                = $ResUCount;
                        'Tag Name'                  = [string]$Tag.Name;
                        'Tag Value'                 = [string]$Tag.Value
                    }
                    $obj
                    if ($ResUCount -eq 1) { $ResUCount = 0 }
                }
            }
            $tmp
        }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('LighthouseTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range D:D,H:H -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Registration Name')
        $Exc.Add('Description')
        $Exc.Add('Registration ID')
        $Exc.Add('Managed By Tenant ID')
        $Exc.Add('Managed By Tenant Name')
        $Exc.Add('Authorizations')
        $Exc.Add('Authorization Count')
        $Exc.Add('Eligible Authorizations')
        $Exc.Add('Provisioning State')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Lighthouse Delegations' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}

<#
.Synopsis
Inventory for Azure Management Groups

.DESCRIPTION
This script consolidates information for all Management Groups in the tenant hierarchy.
Excel Sheet Name: Management Groups

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/ManagementGroups.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        # Management Groups are tenant-level, not subscription-based
        # Use Get-AzManagementGroup with -Expand and -Recurse to get full hierarchy
        $mgmtGroups = Get-AzManagementGroup -Expand -Recurse -ErrorAction SilentlyContinue

    <######### Insert the resource Process here ########>

    if($mgmtGroups)
        {
            $tmp = foreach ($mg in $mgmtGroups) {
                $ResUCount = 1

                # Parse hierarchy path
                $parentPath = if ($mg.ParentName) { $mg.ParentName } else { 'Tenant Root' }

                # Count direct children
                $childMGCount = if ($mg.Children) { ($mg.Children | Where-Object {$_.Type -like '*managementGroups'}).Count } else { 0 }
                $childSubCount = if ($mg.Children) { ($mg.Children | Where-Object {$_.Type -like '*subscriptions'}).Count } else { 0 }

                # Get all subscriptions under this MG (recursively)
                $allSubs = @()
                function Get-AllSubs($node) {
                    if ($node.Children) {
                        foreach ($child in $node.Children) {
                            if ($child.Type -like '*subscriptions') {
                                $allSubs += $child
                            } elseif ($child.Type -like '*managementGroups') {
                                Get-AllSubs $child
                            }
                        }
                    }
                }
                Get-AllSubs $mg
                $totalSubsCount = $allSubs.Count

                $obj = @{
                    'ID'                        = $mg.Id;
                    'Management Group ID'       = $mg.Name;
                    'Display Name'              = $mg.DisplayName;
                    'Parent Management Group'   = $parentPath;
                    'Type'                      = $mg.Type;
                    'Tenant ID'                 = $mg.TenantId;
                    'Direct Child MGs'          = $childMGCount;
                    'Direct Subscriptions'      = $childSubCount;
                    'Total Subscriptions'       = $totalSubsCount;
                    'Updated Time'              = if ($mg.UpdatedTime) { ([datetime]$mg.UpdatedTime).ToString("yyyy-MM-dd HH:mm") } else { $null };
                    'Updated By'                = $mg.UpdatedBy;
                    'Resource U'                = $ResUCount;
                }
                $obj
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

        $TableName = ('MgmtGroupsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Management Group ID')
        $Exc.Add('Display Name')
        $Exc.Add('Parent Management Group')
        $Exc.Add('Type')
        $Exc.Add('Tenant ID')
        $Exc.Add('Direct Child MGs')
        $Exc.Add('Direct Subscriptions')
        $Exc.Add('Total Subscriptions')
        $Exc.Add('Updated Time')
        $Exc.Add('Updated By')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Management Groups' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style

    }
}

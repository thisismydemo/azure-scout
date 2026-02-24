<#
.Synopsis
Inventory for Azure Management Groups

.DESCRIPTION
This script consolidates information for all Management Groups in the tenant hierarchy.
Excel Sheet Name: Management Groups

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Management/ManagementGroups.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Management

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

    # Retrieve the tenant root MG with full hierarchy in a single call
    $tenantRootMG = $null
    try {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if ($ctx -and $ctx.Tenant) {
            $tenantRootMG = Get-AzManagementGroup -GroupId $ctx.Tenant.Id -Expand -Recurse -ErrorAction SilentlyContinue
        }
    } catch {}

    # Fallback: enumerate all top-level MGs if root lookup fails
    if (-not $tenantRootMG) {
        $tenantRootMG = Get-AzManagementGroup -Expand -Recurse -ErrorAction SilentlyContinue
    }

    <######### Insert the resource Process here ########>

    # Recursive helper: flatten the MG tree into a list with depth & path metadata
    function Expand-MgHierarchy {
        param($Node, [int]$Depth = 0, [string]$ParentPath = '')

        if (-not $Node) { return }

        $NodePath = if ($ParentPath) { "$ParentPath / $($Node.DisplayName)" } else { $Node.DisplayName }
        $Indent   = ('    ' * $Depth)   # 4 spaces per level for visual hierarchy

        $directMGs   = @($Node.Children | Where-Object { $_.Type -like '*managementGroups' })
        $directSubs  = @($Node.Children | Where-Object { $_.Type -like '*subscriptions' })
        $directSubNames = ($directSubs | ForEach-Object { $_.DisplayName }) -join ', '

        [PSCustomObject]@{
            'Management Group ID'          = $Node.Name
            'Display Name'                 = "$Indent$($Node.DisplayName)"
            'Display Name (Raw)'           = $Node.DisplayName
            'Full Path'                    = $NodePath
            'Hierarchy Depth'              = $Depth
            'Parent Management Group'      = if ($Node.ParentName) { $Node.ParentDisplayName } else { 'Tenant Root' }
            'Tenant ID'                    = $Node.TenantId
            'Direct Child MGs'             = $directMGs.Count
            'Direct Subscriptions'         = $directSubs.Count
            'Direct Subscription Names'    = $directSubNames
        }

        foreach ($child in $directMGs) {
            Expand-MgHierarchy -Node $child -Depth ($Depth + 1) -ParentPath $NodePath
        }
    }

    $flatHierarchy = @()
    if ($tenantRootMG) {
        if ($tenantRootMG -is [array]) {
            foreach ($root in $tenantRootMG) {
                $flatHierarchy += Expand-MgHierarchy -Node $root
            }
        } else {
            $flatHierarchy = @(Expand-MgHierarchy -Node $tenantRootMG)
        }
    }

    if ($flatHierarchy) {
        $tmp = foreach ($1 in $flatHierarchy) {
            $obj = @{
                'Management Group ID'          = $1.'Management Group ID';
                'Display Name'                 = $1.'Display Name';
                'Display Name (Raw)'           = $1.'Display Name (Raw)';
                'Full Path'                    = $1.'Full Path';
                'Hierarchy Depth'              = $1.'Hierarchy Depth';
                'Parent Management Group'      = $1.'Parent Management Group';
                'Tenant ID'                    = $1.'Tenant ID';
                'Direct Child MGs'             = $1.'Direct Child MGs';
                'Direct Subscriptions'         = $1.'Direct Subscriptions';
                'Direct Subscription Names'    = $1.'Direct Subscription Names';
                'Resource U'                   = 1;
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

    if ($SmaResources)
    {
        $TableName = ('MgmtGroupsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style     = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Management Group ID')
        $Exc.Add('Display Name')
        $Exc.Add('Display Name (Raw)')
        $Exc.Add('Full Path')
        $Exc.Add('Hierarchy Depth')
        $Exc.Add('Parent Management Group')
        $Exc.Add('Tenant ID')
        $Exc.Add('Direct Child MGs')
        $Exc.Add('Direct Subscriptions')
        $Exc.Add('Direct Subscription Names')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Management Groups' `
            -AutoSize `
            -MaxAutoSizeRows 100 `
            -TableName $TableName `
            -TableStyle $TableStyle `
            -Style $Style
    }
}

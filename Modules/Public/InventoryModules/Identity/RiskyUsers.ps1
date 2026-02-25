<#
.Synopsis
Inventory for Entra ID Risky Users

.DESCRIPTION
This script consolidates information for all entra/riskyusers resources.
Excel Sheet Name: Risky Users

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/RiskyUsers.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: AzureScout Contributors
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraRisky = $Resources | Where-Object { $_.TYPE -eq 'entra/riskyusers' }

    if ($entraRisky)
    {
        $tmp = foreach ($1 in $entraRisky) {
            $ResUCount = 1
            $data = $1.properties

            $obj = @{
                'ID'                          = $1.id;
                'Tenant ID'                   = $1.tenantId;
                'User Principal Name'         = $data.userPrincipalName;
                'User Display Name'           = $data.userDisplayName;
                'Risk Level'                  = $data.riskLevel;
                'Risk State'                  = $data.riskState;
                'Risk Detail'                 = $data.riskDetail;
                'Risk Last Updated DateTime'  = $data.riskLastUpdatedDateTime;
                'Is Deleted'                  = [string]$data.isDeleted;
                'Is Processing'               = [string]$data.isProcessing;
                'Resource U'                  = $ResUCount
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
        $TableName = ('RiskyUsersTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText high -Range E:E
        $condtxt += New-ConditionalText medium -Range E:E

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('User Principal Name')
        $Exc.Add('User Display Name')
        $Exc.Add('Risk Level')
        $Exc.Add('Risk State')
        $Exc.Add('Risk Detail')
        $Exc.Add('Risk Last Updated DateTime')
        $Exc.Add('Is Deleted')
        $Exc.Add('Is Processing')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Risky Users' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}

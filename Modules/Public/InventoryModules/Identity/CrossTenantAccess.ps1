<#
.Synopsis
Inventory for Entra ID Cross-Tenant Access Settings

.DESCRIPTION
This script consolidates information for all entra/crosstenantaccess resources.
Excel Sheet Name: Cross-Tenant Access

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/CrossTenantAccess.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: Product Technology Team
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraCTA = $Resources | Where-Object { $_.TYPE -eq 'entra/crosstenantaccess' }

    if ($entraCTA)
    {
        $tmp = foreach ($1 in $entraCTA) {
            $ResUCount = 1
            $data = $1.properties

            # Extract inbound trust settings
            $inboundTrust = ''
            if ($data.inboundTrust) {
                $trustParts = @()
                if ($data.inboundTrust.isMfaAccepted) { $trustParts += 'MFA' }
                if ($data.inboundTrust.isCompliantDeviceAccepted) { $trustParts += 'CompliantDevice' }
                if ($data.inboundTrust.isHybridAzureADJoinedDeviceAccepted) { $trustParts += 'HybridAADJoined' }
                $inboundTrust = ($trustParts -join ', ')
            }

            # B2B Collaboration
            $b2bCollab = ''
            if ($data.b2bCollaborationInbound) {
                $b2bCollab = if ($data.b2bCollaborationInbound.applications.accessType) { $data.b2bCollaborationInbound.applications.accessType } else { 'Not Configured' }
            }

            # B2B Direct Connect
            $b2bDirect = ''
            if ($data.b2bDirectConnectInbound) {
                $b2bDirect = if ($data.b2bDirectConnectInbound.applications.accessType) { $data.b2bDirectConnectInbound.applications.accessType } else { 'Not Configured' }
            }

            $obj = @{
                'ID'                     = $1.id;
                'Tenant ID'              = $1.tenantId;
                'Partner Tenant ID'      = $data.tenantId;
                'Display Name'           = $1.name;
                'Inbound Trust'          = $inboundTrust;
                'B2B Collaboration'      = $b2bCollab;
                'B2B Direct Connect'     = $b2bDirect;
                'Is Service Provider'    = [bool]$data.isServiceProvider;
                'Resource U'             = $ResUCount
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
        $TableName = ('CTATable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Partner Tenant ID')
        $Exc.Add('Inbound Trust')
        $Exc.Add('B2B Collaboration')
        $Exc.Add('B2B Direct Connect')
        $Exc.Add('Is Service Provider')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Cross-Tenant Access' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}

<#
.Synopsis
Inventory for Azure Local Virtual Machine Instances

.DESCRIPTION
This script consolidates information for all microsoft.azurestackhci/virtualmachineinstances resource provider in $Resources variable.
Excel Sheet Name: AzLocal VMs

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AzureLocal/VirtualMachines.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $hciVMs = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurestackhci/virtualmachineinstances' }

    if ($hciVMs) {
        $tmp = foreach ($1 in $hciVMs) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $Retired = $Retirements | Where-Object { $_.id -eq $1.id }
            if ($Retired) {
                $RetiredFeature = foreach ($Retire in $Retired) {
                    $RetiredServiceID = $Unsupported | Where-Object { $_.Id -eq $Retired.ServiceID }
                    [pscustomobject]@{
                        'RetiredFeature' = $RetiredServiceID.RetiringFeature
                        'RetiredDate'    = $RetiredServiceID.RetirementDate
                    }
                }
                $RetiringFeature = if ($RetiredFeature.RetiredFeature.count -gt 1) { $RetiredFeature.RetiredFeature | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredFeature }
                $RetiringFeature = [string]$RetiringFeature
                $RetiringFeature = if ($RetiringFeature -like '* ,*') { $RetiringFeature -replace ".$" } else { $RetiringFeature }

                $RetiringDate = if ($RetiredFeature.RetiredDate.count -gt 1) { $RetiredFeature.RetiredDate | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredDate }
                $RetiringDate = [string]$RetiringDate
                $RetiringDate = if ($RetiringDate -like '* ,*') { $RetiringDate -replace ".$" } else { $RetiringDate }
            }
            else {
                $RetiringFeature = $null
                $RetiringDate = $null
            }

            # Hardware profile
            $VMSize = $data.hardwareProfile.vmSize
            $ProcessorCount = $data.hardwareProfile.processors
            $MemoryMB = $data.hardwareProfile.memoryMB

            # Dynamic memory
            $DynamicMemory = if ($data.hardwareProfile.dynamicMemoryConfig) {
                'Enabled'
            } else { 'Disabled' }
            $DynMemMin = $data.hardwareProfile.dynamicMemoryConfig.minimumMemoryMB
            $DynMemMax = $data.hardwareProfile.dynamicMemoryConfig.maximumMemoryMB

            # OS profile
            $OSType = $data.osProfile.osType
            $ComputerName = $data.osProfile.computerName

            # Storage
            $DataDiskCount = if ($data.storageProfile.dataDisks) { $data.storageProfile.dataDisks.Count } else { 0 }
            $ImageRef = if ($data.storageProfile.imageReference) {
                '{0}/{1}/{2}' -f $data.storageProfile.imageReference.publisher, $data.storageProfile.imageReference.offer, $data.storageProfile.imageReference.sku
            } else { $null }

            # Network interfaces
            $NICs = if ($data.networkProfile.networkInterfaces) {
                ($data.networkProfile.networkInterfaces | ForEach-Object { $_.id.split("/")[-1] }) -join ', '
            } else { $null }

            # Status
            $PowerState = $data.instanceView.powerState
            $ProvisioningState = $data.provisioningState
            $StatusMsg = $data.status.provisioningStatus.status

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                   = $1.id;
                    'Subscription'         = $sub1.name;
                    'Resource Group'       = $1.RESOURCEGROUP;
                    'Name'                 = $1.NAME;
                    'Location'             = $1.LOCATION;
                    'Retiring Feature'     = $RetiringFeature;
                    'Retiring Date'        = $RetiringDate;
                    'Power State'          = $PowerState;
                    'Provisioning State'   = $ProvisioningState;
                    'VM Size'              = $VMSize;
                    'OS Type'              = $OSType;
                    'Computer Name'        = $ComputerName;
                    'Processor Count'      = $ProcessorCount;
                    'Memory MB'            = $MemoryMB;
                    'Dynamic Memory'       = $DynamicMemory;
                    'Dynamic Mem Min MB'   = $DynMemMin;
                    'Dynamic Mem Max MB'   = $DynMemMax;
                    'Data Disk Count'      = $DataDiskCount;
                    'Image Reference'      = $ImageRef;
                    'Network Interfaces'   = $NICs;
                    'Status'               = $StatusMsg;
                    'Resource U'           = $ResUCount;
                    'Tag Name'             = [string]$Tag.Name;
                    'Tag Value'            = [string]$Tag.Value
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

<######## Resource Excel Reporting Begins Here ########>

Else {
    if ($SmaResources) {

        $TableName = ('AzLocalVMs_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Power State')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Provisioning State')
        $Exc.Add('VM Size')
        $Exc.Add('OS Type')
        $Exc.Add('Computer Name')
        $Exc.Add('Processor Count')
        $Exc.Add('Memory MB')
        $Exc.Add('Dynamic Memory')
        $Exc.Add('Dynamic Mem Min MB')
        $Exc.Add('Dynamic Mem Max MB')
        $Exc.Add('Data Disk Count')
        $Exc.Add('Image Reference')
        $Exc.Add('Network Interfaces')
        $Exc.Add('Status')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'AzLocal VMs' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}

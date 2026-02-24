<#
.Synopsis
Inventory for AVD Session Hosts on Azure Local and Arc-Enabled Infrastructure

.DESCRIPTION
This script identifies Azure Virtual Desktop session hosts running on Azure Local
(Azure Stack HCI) or Arc-enabled infrastructure by inspecting virtual machine
instances and connected Arc machines that are tagged or configured as AVD session hosts.
Excel Sheet Name: AVD on Azure Local/Arc

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Compute/AVDAzureLocal.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Compute

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    # Arc-enabled machines tagged as AVD session hosts
    $arcAvd = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.hybridcompute/machines' -and
        (
            $_.tags.'AvdSessionHost' -eq 'true' -or
            $_.tags.'avdsessionhost' -eq 'true' -or
            $_.tags.'AVDSessionHost' -eq 'true'
        )
    }

    # Azure Local (HCI) VM instances tagged as AVD session hosts
    $hciAvd = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.azurestackhci/virtualmachineinstances' -and
        (
            $_.tags.'AvdSessionHost' -eq 'true' -or
            $_.tags.'avdsessionhost' -eq 'true' -or
            $_.tags.'AVDSessionHost' -eq 'true'
        )
    }

    # Also pick up HCI VMs in host pools via the session host API
    $avdSessionHosts = $Resources | Where-Object { $_.TYPE -eq 'microsoft.desktopvirtualization/hostpools/sessionhosts' }

    $combined = @()
    if ($arcAvd)  { $combined += $arcAvd  | ForEach-Object { $_ | Add-Member -NotePropertyName '_Platform' -NotePropertyValue 'Arc'        -Force -PassThru } }
    if ($hciAvd)  { $combined += $hciAvd  | ForEach-Object { $_ | Add-Member -NotePropertyName '_Platform' -NotePropertyValue 'AzureLocal'  -Force -PassThru } }

    # Fallback: pick up registered session hosts whose resource ID points to an Arc/HCI VM
    if ($avdSessionHosts) {
        foreach ($sh in $avdSessionHosts) {
            $shProp = $sh.properties
            $vmId   = if ($shProp.resourceId) { $shProp.resourceId } elseif ($shProp.objectId) { $shProp.objectId } else { $null }
            if ($vmId -and ($vmId -like '*/hybridCompute/*' -or $vmId -like '*/AzureStackHCI/*')) {
                $platform = if ($vmId -like '*/hybridCompute/*') { 'Arc' } else { 'AzureLocal' }
                $synth = [PSCustomObject]@{
                    TYPE          = 'avd/sessionhost'
                    NAME          = $sh.NAME
                    RESOURCEGROUP = $sh.RESOURCEGROUP
                    LOCATION      = $sh.LOCATION
                    subscriptionId= $sh.subscriptionId
                    tags          = $sh.tags
                    PROPERTIES    = $shProp
                    _Platform     = $platform
                    _VmId         = $vmId
                    _HostPool     = ($sh.id -split '/')[8]
                }
                $combined += $synth
            }
        }
    }

    if ($combined) {
        $tmp = foreach ($1 in $combined) {
            $ResUCount = 1
            $sub1      = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data      = $1.PROPERTIES
            $Tags      = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $hostPool   = if ($1._HostPool) { $1._HostPool } elseif ($data.hostPoolId)   { ($data.hostPoolId   -split '/')[-1] } else { $1.tags.'HostPool' }
            $arcVersion = if ($data.agentVersion)   { $data.agentVersion }   else { $data.agentversion }
            $osVersion  = if ($data.osVersion)       { $data.osVersion }      else { $data.osversion }
            $hciCluster = if ($1._Platform -eq 'AzureLocal') {
                # Walk up the resource ID to find the HCI cluster name
                if ($1.id) { ($1.id -split '/')[8] } else { 'N/A' }
            } else { 'N/A' }

            $hbRaw     = $data.lastStatusChange
            $heartbeat = if ($hbRaw) { try { ([datetime]$hbRaw).ToString('yyyy-MM-dd HH:mm') } catch { $hbRaw } } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'Name'                  = $1.NAME;
                    'Subscription'          = $sub1.Name;
                    'Resource Group'        = $1.RESOURCEGROUP;
                    'Location'              = $1.LOCATION;
                    'Platform'              = $1._Platform;
                    'Host Pool'             = if ($hostPool) { $hostPool } else { 'N/A' };
                    'Status'                = if ($data.status)         { $data.status }          else { 'N/A' };
                    'Agent Version'         = if ($arcVersion)          { $arcVersion }            else { 'N/A' };
                    'Last Heartbeat'        = $heartbeat;
                    'OS Version'            = if ($osVersion)           { $osVersion }             else { 'N/A' };
                    'Azure Local Cluster'   = $hciCluster;
                    'Allow New Session'     = if ($data.allowNewSession -ne $null) { $data.allowNewSession } else { 'N/A' };
                    'Assigned User'         = if ($data.assignedUser)   { $data.assignedUser }    else { 'N/A' };
                    'Sessions'              = if ($data.sessions -ne $null) { $data.sessions }     else { 0 };
                    'Resource ID'           = if ($1._VmId)             { $1._VmId }               else { $1.id };
                    'Resource U'            = $ResUCount;
                    'Tag Name'              = [string]$Tag.Name;
                    'Tag Value'             = [string]$Tag.Value;
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AVDAzureLocalTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style     = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Location')
        $Exc.Add('Platform')
        $Exc.Add('Host Pool')
        $Exc.Add('Status')
        $Exc.Add('Agent Version')
        $Exc.Add('Last Heartbeat')
        $Exc.Add('OS Version')
        $Exc.Add('Azure Local Cluster')
        $Exc.Add('Allow New Session')
        $Exc.Add('Assigned User')
        $Exc.Add('Sessions')
        $Exc.Add('Resource ID')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD on Azure Local/Arc' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}

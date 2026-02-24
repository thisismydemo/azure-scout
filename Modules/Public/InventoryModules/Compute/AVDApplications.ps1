<#
.Synopsis
Inventory for Azure Virtual Desktop Applications (RemoteApp)

.DESCRIPTION
This script retrieves all RemoteApp applications within AVD Application Groups
via the ARM REST API (microsoft.desktopvirtualization/applicationgroups/applications).
Excel Sheet Name: AVD Applications

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Compute/AVDApplications.ps1

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
    # Only RemoteApp application groups have applications
    $appGroups = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.desktopvirtualization/applicationgroups' -and
        $_.PROPERTIES.applicationGroupType -eq 'RemoteApp'
    }

    if ($appGroups) {
        $tmp = foreach ($ag in $appGroups) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ag.subscriptionId }

            $apiVersion = '2022-09-09'
            $uri = "/subscriptions/$($ag.subscriptionId)/resourceGroups/$($ag.RESOURCEGROUP)/providers/Microsoft.DesktopVirtualization/applicationGroups/$($ag.NAME)/applications?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result = $response.Content | ConvertFrom-Json
                    $apps   = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $apps) {
                        $ResUCount = 1
                        $aProp = $1.properties

                        $obj = @{
                            'App Group Name'           = $ag.NAME;
                            'Subscription'             = $sub1.Name;
                            'Resource Group'           = $ag.RESOURCEGROUP;
                            'Application Name'         = $1.name;
                            'Friendly Name'            = if ($aProp.friendlyName)          { $aProp.friendlyName }          else { 'N/A' };
                            'Description'              = if ($aProp.description)           { $aProp.description }           else { 'N/A' };
                            'App Alias'                = if ($aProp.applicationType)       { $aProp.applicationType }       else { 'N/A' };
                            'Executable Path'          = if ($aProp.filePath)              { $aProp.filePath }              else { 'N/A' };
                            'Command Line Setting'     = if ($aProp.commandLineSetting)    { $aProp.commandLineSetting }    else { 'N/A' };
                            'Command Line Arguments'   = if ($aProp.commandLineArguments)  { $aProp.commandLineArguments }  else { 'N/A' };
                            'Icon Path'                = if ($aProp.iconPath)              { $aProp.iconPath }              else { 'N/A' };
                            'Show In Portal'           = if ($aProp.showInPortal -eq $true){ 'Yes' }                        else { 'No' };
                            'Resource U'               = $ResUCount;
                            'Tag Name'                 = '';
                            'Tag Value'                = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("AVDApplications: Failed for $($ag.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AVDApplicationsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('App Group Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Application Name')
        $Exc.Add('Friendly Name')
        $Exc.Add('Description')
        $Exc.Add('Executable Path')
        $Exc.Add('Command Line Setting')
        $Exc.Add('Command Line Arguments')
        $Exc.Add('Icon Path')
        $Exc.Add('Show In Portal')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD Applications' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}

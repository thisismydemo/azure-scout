<#
.Synopsis
Inventory for Azure Policy Compliance States

.DESCRIPTION
This script consolidates information for all Azure Policy compliance states across subscriptions.
Excel Sheet Name: Policy Compliance

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Management/PolicyComplianceStates.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

.CATEGORY Management

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        # Get all policy assignments and their compliance states
        $tmp = @()

        foreach ($subscription in $Sub) {
            try {
                Set-AzContext -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue | Out-Null

                # Get policy states for this subscription
                $policyStates = Get-AzPolicyState -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue

                if ($policyStates) {
                    foreach ($state in $policyStates) {
                        $ResUCount = 1

                        # Parse policy assignment info
                        $assignmentName = if ($state.PolicyAssignmentName) { $state.PolicyAssignmentName } else { 'N/A' }
                        $policyDefName = if ($state.PolicyDefinitionName) { $state.PolicyDefinitionName } else { 'N/A' }

                        $obj = @{
                            'Subscription'              = $subscription.Name;
                            'Subscription ID'           = $subscription.Id;
                            'Resource ID'               = $state.ResourceId;
                            'Resource Type'             = $state.ResourceType;
                            'Resource Location'         = $state.ResourceLocation;
                            'Resource Group'            = $state.ResourceGroup;
                            'Policy Assignment ID'      = $state.PolicyAssignmentId;
                            'Policy Assignment Name'    = $assignmentName;
                            'Policy Definition ID'      = $state.PolicyDefinitionId;
                            'Policy Definition Name'    = $policyDefName;
                            'Policy Set Definition ID'  = $state.PolicySetDefinitionId;
                            'Compliance State'          = $state.ComplianceState;
                            'Is Compliant'              = $state.IsCompliant;
                            'Policy Definition Action'  = $state.PolicyDefinitionAction;
                            'Policy Definition Category'= $state.PolicyDefinitionCategory;
                            'Timestamp'                 = if ($state.Timestamp) { ([datetime]$state.Timestamp).ToString("yyyy-MM-dd HH:mm") } else { $null };
                            'Management Group IDs'      = if ($state.ManagementGroupIds) { ($state.ManagementGroupIds -join '; ') } else { 'None' };
                            'Resource U'                = $ResUCount;
                        }
                        $tmp += $obj
                    }
                }
            }
            catch {
                Write-Warning "Failed to get policy states for subscription: $($subscription.Name)"
            }
        }

    <######### Insert the resource Process here ########>

    if($tmp)
        {
            $tmp
        }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('PolicyCompTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range C:C -Width 80 -WrapText

        $condtxt = @()
        # Highlight non-compliant resources
        $condtxt += New-ConditionalText -Text 'NonCompliant' -Range L:L -ConditionalType ContainsText -BackgroundColor Yellow
        $condtxt += New-ConditionalText -Text 'False' -Range M:M -ConditionalType ContainsText -BackgroundColor Yellow

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Subscription ID')
        $Exc.Add('Resource ID')
        $Exc.Add('Resource Type')
        $Exc.Add('Resource Location')
        $Exc.Add('Resource Group')
        $Exc.Add('Policy Assignment ID')
        $Exc.Add('Policy Assignment Name')
        $Exc.Add('Policy Definition ID')
        $Exc.Add('Policy Definition Name')
        $Exc.Add('Policy Set Definition ID')
        $Exc.Add('Compliance State')
        $Exc.Add('Is Compliant')
        $Exc.Add('Policy Definition Action')
        $Exc.Add('Policy Definition Category')
        $Exc.Add('Timestamp')
        $Exc.Add('Management Group IDs')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Policy Compliance' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style, $StyleExt

    }
}

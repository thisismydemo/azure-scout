<#
.Synopsis
Inventory for Microsoft Defender for Cloud Security Assessments

.DESCRIPTION
This script consolidates information for all security assessments from Microsoft Defender for Cloud.
Captures security recommendations, severity, remediation steps, and compliance impact.
Excel Sheet Name: Defender Assessments

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Security/DefenderAssessments.ps1

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

        # Get security assessments from Microsoft Defender for Cloud
        $assessments = @()

        foreach ($subscription in $Sub) {
            Write-AZTILog -Message "  >> Processing Defender Assessments for subscription: $($subscription.Name)" -Color 'Cyan'

            try {
                $subAssessments = Get-AzSecurityAssessment -ErrorAction SilentlyContinue | Where-Object { $_.Id -match "/subscriptions/$($subscription.Id)/" }
                if ($subAssessments) {
                    $assessments += $subAssessments
                }
            } catch {
                Write-AZTILog -Message "    Failed to retrieve assessments: $_" -Color 'Yellow'
            }
        }

    <######### Insert the resource Process here ########>

    if($assessments)
        {
            $tmp = foreach ($1 in $assessments) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq ($1.Id -split '/')[2] }
                $data = $1

                # Extract resource details from ID
                $resourceId = if ($data.ResourceDetails.Id) { $data.ResourceDetails.Id } else { 'Subscription-level' }
                $resourceType = if ($resourceId -ne 'Subscription-level') {
                    ($resourceId -split '/')[6..7] -join '/'
                } else { 'Subscription' }

                $resourceName = if ($resourceId -ne 'Subscription-level') {
                    ($resourceId -split '/')[-1]
                } else { $sub1.Name }

                $resourceGroup = if ($resourceId -match '/resourceGroups/([^/]+)') {
                    $Matches[1]
                } else { 'N/A' }

                # Parse status and severity
                $status = $data.Status.Code
                $severity = $data.Status.Severity
                $healthyStatus = if ($status -eq 'Healthy') { 'Compliant' } elseif ($status -eq 'Unhealthy') { 'Non-Compliant' } else { 'Not Applicable' }

                # Get remediation steps
                $remediationSteps = if ($data.Status.Description) {
                    $data.Status.Description
                } else {
                    'See Azure Portal for details'
                }

                # Get affected resources count
                $affectedResources = if ($data.AdditionalData.AssessedResourceType) {
                    $data.AdditionalData.AssessedResourceType
                } else { 'N/A' }

                $obj = @{
                    'ID'                        = $1.Name;
                    'Subscription'              = $sub1.Name;
                    'Assessment Name'           = $data.DisplayName;
                    'Category'                  = if ($data.Metadata.Category) { $data.Metadata.Category -join ', ' } else { 'General' };
                    'Severity'                  = $severity;
                    'Status'                    = $healthyStatus;
                    'Resource Name'             = $resourceName;
                    'Resource Type'             = $resourceType;
                    'Resource Group'            = $resourceGroup;
                    'Remediation'               = $remediationSteps;
                    'Implementation Effort'     = if ($data.Metadata.ImplementationEffort) { $data.Metadata.ImplementationEffort } else { 'N/A' };
                    'User Impact'               = if ($data.Metadata.UserImpact) { $data.Metadata.UserImpact } else { 'N/A' };
                    'Threats'                   = if ($data.Metadata.Threats) { $data.Metadata.Threats -join ', ' } else { 'N/A' };
                    'Compliance Standards'      = if ($data.Metadata.AssessmentType) { $data.Metadata.AssessmentType } else { 'N/A' };
                    'Portal Link'               = "https://portal.azure.com/#blade/Microsoft_Azure_Security/RecommendationsBlade/assessmentKey/$($1.Name)";
                    'Resource U'                = $ResUCount;
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
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('DefenderAssessTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range J:J -Width 50 -WrapText

        # Conditional formatting for severity and status
        $condSeverity = New-ConditionalText -Text 'High' -BackgroundColor '#FFC7CE' -ConditionalTextColor '#9C0006'
        $condStatus = New-ConditionalText -Text 'Non-Compliant' -BackgroundColor '#FFC7CE' -ConditionalTextColor '#9C0006'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Assessment Name')
        $Exc.Add('Category')
        $Exc.Add('Severity')
        $Exc.Add('Status')
        $Exc.Add('Resource Name')
        $Exc.Add('Resource Type')
        $Exc.Add('Resource Group')
        $Exc.Add('Remediation')
        $Exc.Add('Implementation Effort')
        $Exc.Add('User Impact')
        $Exc.Add('Threats')
        $Exc.Add('Compliance Standards')
        $Exc.Add('Portal Link')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Defender Assessments' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt -ConditionalText $condSeverity, $condStatus

    }
}

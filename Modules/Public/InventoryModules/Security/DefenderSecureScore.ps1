<#
.Synopsis
Inventory for Microsoft Defender for Cloud Secure Score

.DESCRIPTION
This script consolidates Secure Score data from Microsoft Defender for Cloud.
Captures overall secure score, security controls, max scores, and current achievements.
Excel Sheet Name: Defender Secure Score

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Security/DefenderSecureScore.ps1

.COMPONENT
This powershell Module is part of Azure Scout (AZSC)

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

        # Get secure score data from Microsoft Defender for Cloud
        $secureScores = @()

        foreach ($subscription in $Sub) {
            Write-AZSCLog -Message "  >> Processing Defender Secure Score for subscription: $($subscription.Name)" -Color 'Cyan'

            try {
                $subScore = Get-AzSecuritySecureScore -ErrorAction SilentlyContinue
                if ($subScore) {
                    $secureScores += $subScore | ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'SubscriptionId' -NotePropertyValue $subscription.Id -Force -PassThru
                    }
                }
            } catch {
                Write-AZSCLog -Message "    Failed to retrieve secure score: $_" -Color 'Yellow'
            }
        }

    <######### Insert the resource Process here ########>

    if($secureScores)
        {
            $tmp = foreach ($1 in $secureScores) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.SubscriptionId }
                $data = $1

                # Calculate score percentage
                $currentScore = if ($data.Score.Current) { [math]::Round($data.Score.Current, 2) } else { 0 }
                $maxScore = if ($data.Score.Max) { [math]::Round($data.Score.Max, 2) } else { 0 }
                $scorePercentage = if ($maxScore -gt 0) {
                    [math]::Round(($currentScore / $maxScore) * 100, 2)
                } else { 0 }

                # Get security controls
                $securityControls = @()
                if ($data.Score.Percentage -ne $null) {
                    try {
                        $controls = Get-AzSecuritySecureScoreControl -ErrorAction SilentlyContinue
                        if ($controls) {
                            foreach ($control in $controls) {
                                $controlScore = if ($control.Score.Current) { [math]::Round($control.Score.Current, 2) } else { 0 }
                                $controlMax = if ($control.Score.Max) { [math]::Round($control.Score.Max, 2) } else { 0 }
                                $controlPercentage = if ($controlMax -gt 0) {
                                    [math]::Round(($controlScore / $controlMax) * 100, 2)
                                } else { 0 }

                                $securityControls += [PSCustomObject]@{
                                    ControlName = $control.DisplayName
                                    CurrentScore = $controlScore
                                    MaxScore = $controlMax
                                    Percentage = $controlPercentage
                                    HealthyResources = if ($control.Score.HealthyResourceCount) { $control.Score.HealthyResourceCount } else { 0 }
                                    UnhealthyResources = if ($control.Score.UnhealthyResourceCount) { $control.Score.UnhealthyResourceCount } else { 0 }
                                }
                            }
                        }
                    } catch {
                        Write-AZSCLog -Message "    Failed to retrieve security controls: $_" -Color 'Yellow'
                    }
                }

                $obj = @{
                    'ID'                        = $1.Name;
                    'Subscription'              = $sub1.Name;
                    'Secure Score Name'         = $data.DisplayName;
                    'Current Score'             = $currentScore;
                    'Max Score'                 = $maxScore;
                    'Score Percentage'          = "$scorePercentage%";
                    'Healthy Resources'         = if ($data.Score.HealthyResourceCount) { $data.Score.HealthyResourceCount } else { 0 };
                    'Unhealthy Resources'       = if ($data.Score.UnhealthyResourceCount) { $data.Score.UnhealthyResourceCount } else { 0 };
                    'Not Applicable Resources'  = if ($data.Score.NotApplicableResourceCount) { $data.Score.NotApplicableResourceCount } else { 0 };
                    'Weight'                    = if ($data.Weight) { $data.Weight } else { 'N/A' };
                    'Portal Link'               = "https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/SecureScore";
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

        $TableName = ('DefenderScoreTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        # Conditional formatting for low scores
        $condLowScore = New-ConditionalText -ConditionalType LessThan -Text '50' -Range F:F -BackgroundColor '#FFC7CE' -ConditionalTextColor '#9C0006'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Secure Score Name')
        $Exc.Add('Current Score')
        $Exc.Add('Max Score')
        $Exc.Add('Score Percentage')
        $Exc.Add('Healthy Resources')
        $Exc.Add('Unhealthy Resources')
        $Exc.Add('Not Applicable Resources')
        $Exc.Add('Weight')
        $Exc.Add('Portal Link')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Defender Secure Score' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style -ConditionalText $condLowScore

    }
}

<#
.Synopsis
Module responsible for starting the processing jobs for Azure Resources.

.DESCRIPTION
This module creates and manages jobs to process Azure Resources in batches based on the environment size. It ensures efficient resource processing and avoids CPU overload.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/2.ProcessingFunctions/Start-AZSCProcessJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Start-AZSCProcessJob {
    Param($Resources, $Retirements, $Subscriptions, $DefaultPath, $Heavy, $InTag, $Unsupported, $Category)

    Write-Progress -activity 'Azure Inventory' -Status "22% Complete." -PercentComplete 22 -CurrentOperation "Creating Jobs to Process Data.."

    switch ($Resources.count)
    {
        {$_ -le 12500}
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Regular Size Environment. Jobs will be run in parallel.')
                $EnvSizeLooper = 20
            }
        {$_ -gt 12500 -and $_ -le 50000}
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Medium Size Environment. Jobs will be run in batches of 8.')
                $EnvSizeLooper = 8
            }
        {$_ -gt 50000}
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Large Environment Detected.')
                $EnvSizeLooper = 5
                Write-Host ('Jobs will be run in small batches to avoid CPU and Memory Overload.') -ForegroundColor Red
            }
    }

    if ($Heavy.IsPresent -or $InTag.IsPresent)
        {
            Write-Host ('Heavy Mode or InTag Mode Detected. Jobs will be run in small batches to avoid CPU and Memory Overload.') -ForegroundColor Red
            $EnvSizeLooper = 5
        }

    $ParentPath = (get-item $PSScriptRoot).parent.parent
    $InventoryModulesPath = Join-Path $ParentPath 'Public' 'InventoryModules'
    $ModuleFolders = Get-ChildItem -Path $InventoryModulesPath -Directory

    # Filter to requested categories (default is 'All' = no filtering)
    if ($Category -and $Category -notcontains 'All') {
        $ModuleFolders = $ModuleFolders | Where-Object { $Category -contains $_.Name }
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Category filter applied. Processing folders: '+($ModuleFolders.Name -join ', '))
    }

    $JobLoop = 1
    $TotalFolders = $ModuleFolders.count

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Converting Resource data to JSON for Jobs')
    $NewResources = ($Resources | ConvertTo-Json -Depth 40 -Compress)

    Remove-Variable -Name Resources
    Clear-AZSCMemory

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting to Create Jobs to Process the Resources.')

    #Foreach ($ModuleFolder in $ModuleFolders)
    $ModuleFolders | ForEach-Object -Process {
            $ModuleFolder = $_
            $ModulePath = Join-Path $ModuleFolder.FullName '*.ps1'
            $ModuleName = $ModuleFolder.Name
            $ModuleFiles = Get-ChildItem -Path $ModulePath

            # 18.4.1 — Build per-file module info objects that include .CATEGORY comment metadata.
            # This enriches auto-discovery so callers can inspect categories programmatically and
            # enables fine-grained filtering (cross-category modules in a single folder).
            $ModuleInfoList = $ModuleFiles | ForEach-Object {
                $HeaderLines    = @(Get-Content -Path $_.FullName -TotalCount 50 -ErrorAction SilentlyContinue)
                $HeaderText     = $HeaderLines -join "`n"
                $fileCategory   = $ModuleName  # default: folder name

                if ($HeaderText -match '\.CATEGORY\s*[\r\n]+\s*([^\r\n#<]+)') {
                    $fileCategory = $Matches[1].Trim()
                }

                [PSCustomObject]@{
                    File            = $_
                    Name            = $_.BaseName
                    FolderCategory  = $ModuleName
                    FileCategory    = $fileCategory
                    Categories      = @($fileCategory -split '\s*,\s*')
                }
            }

            # If category filtering is active, further filter at the individual file level using
            # the .CATEGORY header. Files without a .CATEGORY header fall back to folder category.
            if ($Category -and $Category -notcontains 'All') {
                $ModuleInfoList = $ModuleInfoList | Where-Object {
                    ($_.Categories | Where-Object { $Category -contains $_ }).Count -gt 0
                }
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Per-file category filter applied in folder '+$ModuleName+'. Files: '+($ModuleInfoList.Name -join ', '))
            }

            # Unwrap back to FileInfo objects for the job (keeps downstream job code unchanged)
            $ModuleFiles = $ModuleInfoList | Select-Object -ExpandProperty File

            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Creating Job: '+$ModuleName)

            $c = (($JobLoop / $TotalFolders) * 100)
            $c = [math]::Round($c)
            $filesInFolder = $ModuleFiles.Count
            Write-Progress -Id 1 -activity "Creating Jobs" -Status "$c% Complete." -PercentComplete $c -CurrentOperation "Processing module category: $ModuleName ($filesInFolder modules)"

            Start-Job -Name ('ResourceJob_'+$ModuleName) -ScriptBlock {

                $ModuleFiles = $($args[0])
                $Subscriptions = $($args[2])
                $InTag = $($args[3])
                $Resources = $($args[4]) | ConvertFrom-Json
                $Retirements = $($args[5])
                $Task = $($args[6])
                $Unsupported = $($args[10])

                $job = @()

                Foreach ($Module in $ModuleFiles)
                    {
                        $ModuleFileContent = New-Object System.IO.StreamReader($Module.FullName)
                        $ModuleData = $ModuleFileContent.ReadToEnd()
                        $ModuleFileContent.Dispose()
                        $ModName = $Module.Name.replace(".ps1","")

                        New-Variable -Name ('ModRun' + $ModName)
                        New-Variable -Name ('ModJob' + $ModName)

                        Set-Variable -Name ('ModRun' + $ModName) -Value ([PowerShell]::Create()).AddScript($ModuleData).AddArgument($PSScriptRoot).AddArgument($Subscriptions).AddArgument($InTag).AddArgument($Resources).AddArgument($Retirements).AddArgument($Task).AddArgument($null).AddArgument($null).AddArgument($null).AddArgument($Unsupported)

                        Set-Variable -Name ('ModJob' + $ModName) -Value ((get-variable -name ('ModRun' + $ModName)).Value).BeginInvoke()

                        $job += (get-variable -name ('ModJob' + $ModName)).Value
                        Start-Sleep -Milliseconds 100
                        Remove-Variable -Name ModName
                    }

                While ($Job.Runspace.IsCompleted -contains $false) { Start-Sleep -Milliseconds 500 }

                Foreach ($Module in $ModuleFiles)
                    {
                        $ModName = $Module.Name.replace(".ps1","")
                        New-Variable -Name ('ModValue' + $ModName)
                        Set-Variable -Name ('ModValue' + $ModName) -Value (((get-variable -name ('ModRun' + $ModName)).Value).EndInvoke((get-variable -name ('ModJob' + $ModName)).Value))

                        Remove-Variable -Name ('ModRun' + $ModName)
                        Remove-Variable -Name ('ModJob' + $ModName)
                        Start-Sleep -Milliseconds 100
                        Remove-Variable -Name ModName
                    }

                $Hashtable = New-Object System.Collections.Hashtable

                Foreach ($Module in $ModuleFiles)
                    {
                        $ModName = $Module.Name.replace(".ps1","")

                        $Hashtable["$ModName"] = (get-variable -name ('ModValue' + $ModName)).Value

                        Remove-Variable -Name ('ModValue' + $ModName)
                        Start-Sleep -Milliseconds 100

                        Remove-Variable -Name ModName
                    }

                $Hashtable

            } -ArgumentList $ModuleFiles, $PSScriptRoot, $Subscriptions, $InTag, $NewResources , $Retirements, 'Processing', $null, $null, $null, $Unsupported | Out-Null

        if($JobLoop -eq $EnvSizeLooper)
            {
                Write-Host 'Waiting Batch Jobs' -ForegroundColor Cyan -NoNewline
                Write-Host '. This step may take several minutes to finish' -ForegroundColor Cyan

                $InterJobNames = (Get-Job | Where-Object {$_.name -like 'ResourceJob_*' -and $_.State -eq 'Running'}).Name

                Wait-AZSCJob -JobNames $InterJobNames -JobType 'Resource Batch' -LoopTime 5

                $JobNames = (Get-Job | Where-Object {$_.name -like 'ResourceJob_*'}).Name

                Build-AZSCCacheFiles -DefaultPath $DefaultPath -JobNames $JobNames

                $JobLoop = 0
            }
        $JobLoop ++

        }

        Remove-Variable -Name NewResources
        Clear-AZSCMemory
}
#Requires -Version 7.0
<#
.SYNOPSIS
    Regenerates pmo/task-list.md from the live Azure DevOps board and GitHub issues.

.DESCRIPTION
    Azure DevOps and GitHub are the source of truth for Azure Scout work tracking. The task list
    in the docs site is a generated view of that data, not a hand-maintained document.

    The script reads every work item in the Azure Scout ADO project (WIQL + workitemsbatch), pairs
    each one with the GitHub issues hyperlinked to it, and writes a Markdown page grouped by Epic.

    Authentication uses the ambient Azure CLI session for ADO and the GitHub CLI for issues, so no
    PAT is required or stored. Run `az login` and `gh auth login` first.

.PARAMETER OutputPath
    Where to write the generated Markdown. Defaults to pmo/task-list.md in the repo.

.PARAMETER Organization
    Azure DevOps organization URL.

.PARAMETER ProjectId
    Azure DevOps project GUID. The GUID is used rather than the project name because the name
    contains an em-dash that Windows console encoding mangles, which silently queries the wrong
    project.

.PARAMETER Repository
    GitHub repository in owner/name form.

.EXAMPLE
    ./scripts/Build-TaskList.ps1

    Regenerates pmo/task-list.md from the live board.

.EXAMPLE
    ./scripts/Build-TaskList.ps1 -OutputPath ./task-list-preview.md

    Writes the generated view somewhere else so it can be diffed before replacing the committed file.
#>
[CmdletBinding()]
param(
    [string] $OutputPath   = (Join-Path $PSScriptRoot '..' 'pmo' 'task-list.md'),
    [string] $Organization = 'https://dev.azure.com/hybridcloudsolutions',
    [string] $ProjectId    = '85b6e47e-a666-4a38-8c43-de87dd21aa56',
    [string] $Repository   = 'thisismydemo/azure-scout'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Azure DevOps resource GUID - constant across all tenants.
$AdoResource = '499b84ac-1321-427f-aa17-267ca6975798'

function Get-AdoHeader {
    $token = az account get-access-token --resource $AdoResource --query accessToken -o tsv
    if (-not $token) { throw 'Could not get an Azure DevOps access token. Run az login first.' }
    return @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
}

function Get-WorkItem {
    param([hashtable] $Header, [string] $BaseUri)

    # The team-project filter is mandatory: WIQL without it runs at organization scope and returns
    # every work item in every project.
    $wiql = @{
        query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project ORDER BY [System.Id]"
    } | ConvertTo-Json

    $ids = @((Invoke-RestMethod -Uri "$BaseUri/$ProjectId/_apis/wit/wiql?api-version=7.0" `
                -Method POST -Headers $Header -Body $wiql).workItems.id)

    $items = @()
    for ($i = 0; $i -lt $ids.Count; $i += 100) {
        $chunk = $ids[$i..([Math]::Min($i + 99, $ids.Count - 1))]
        $body  = @{ ids = $chunk; '$expand' = 'Relations' } | ConvertTo-Json
        $items += (Invoke-RestMethod -Uri "$BaseUri/$ProjectId/_apis/wit/workitemsbatch?api-version=7.0" `
                    -Method POST -Headers $Header -Body $body).value
    }
    return $items
}

function Get-Field {
    param($WorkItem, [string] $Name, $Default = $null)
    if ($WorkItem.fields.PSObject.Properties.Name -contains $Name) { return $WorkItem.fields.$Name }
    return $Default
}

function ConvertTo-Row {
    param($WorkItem)

    $parent   = $null
    $ghIssues = @()
    if ($WorkItem.PSObject.Properties.Name -contains 'relations' -and $WorkItem.relations) {
        foreach ($rel in $WorkItem.relations) {
            if ($rel.rel -eq 'System.LinkTypes.Hierarchy-Reverse' -and $rel.url -match '/workItems/(\d+)') {
                $parent = [int]$Matches[1]
            }
            if ($rel.rel -eq 'Hyperlink' -and $rel.url -match 'github\.com/[^/]+/[^/]+/issues/(\d+)') {
                $ghIssues += [int]$Matches[1]
            }
        }
    }

    [pscustomobject]@{
        Id       = $WorkItem.id
        Type     = Get-Field $WorkItem 'System.WorkItemType'
        State    = Get-Field $WorkItem 'System.State'
        Title    = Get-Field $WorkItem 'System.Title'
        Priority = Get-Field $WorkItem 'Microsoft.VSTS.Common.Priority' 3
        Area     = (Get-Field $WorkItem 'System.AreaPath' '') -replace '^.*\\', ''
        Tags     = @(((Get-Field $WorkItem 'System.Tags' '') -split ';') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Parent   = $parent
        Github   = ($ghIssues | Sort-Object -Unique)
    }
}

function Get-GitHubState {
    param([string] $Repo)

    # gh issue list spends the GraphQL quota, which is separate from - and smaller in practice than -
    # the REST quota. The REST issues endpoint also returns pull requests, so those get filtered out.
    $state = @{}
    for ($page = 1; $page -le 10; $page++) {
        $raw = (gh api "repos/$Repo/issues?state=all&per_page=100&page=$page" 2>&1 | Out-String)
        $start = $raw.IndexOf('[')
        if ($start -lt 0) { throw "Unexpected response from the GitHub API: $raw" }
        $batch = @($raw.Substring($start) | ConvertFrom-Json)
        if (-not $batch) { break }
        foreach ($issue in $batch) {
            if ($issue.PSObject.Properties.Name -contains 'pull_request') { continue }
            $state[[int]$issue.number] = $issue.state
        }
        if ($batch.Count -lt 100) { break }
    }
    return $state
}

function Format-GitHubLink {
    param([int[]] $Numbers, [hashtable] $State, [string] $Repo)
    if (-not $Numbers) { return '—' }
    $parts = foreach ($n in $Numbers) {
        $mark = if ($State.ContainsKey($n) -and $State[$n] -eq 'closed') { '' } else { ' (open)' }
        "[#$n](https://github.com/$Repo/issues/$n)$mark"
    }
    return ($parts -join ', ')
}

function Format-Title {
    # VitePress compiles Markdown as a Vue template, so a title like "Wire -Assessment <domain>"
    # is parsed as an unclosed HTML tag and fails the build. Escape the angle brackets and the
    # table-cell delimiter.
    param([string] $Text)
    return (($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;') -replace '\|', '\|')
}

function Format-ItemTable {
    param([object[]] $Rows, [hashtable] $GhState, [string] $Repo)
    if (-not $Rows) { return @('_None._', '') }
    $out = @('| Item | Type | P | Area | Title | GitHub |', '|---|---|---|---|---|---|')
    foreach ($r in ($Rows | Sort-Object Id)) {
        $title = Format-Title $r.Title
        $out += "| AB#$($r.Id) | $($r.Type) | $($r.Priority) | $($r.Area) | $title | $(Format-GitHubLink -Numbers $r.Github -State $GhState -Repo $Repo) |"
    }
    $out += ''
    return $out
}

Write-Verbose 'Reading the Azure DevOps board...'
$header = Get-AdoHeader
$rows   = @(Get-WorkItem -Header $header -BaseUri $Organization | ForEach-Object { ConvertTo-Row $_ })
if (-not $rows) { throw 'The board query returned no work items.' }

Write-Verbose 'Reading GitHub issue states...'
$ghState = Get-GitHubState -Repo $Repository

$byId    = @{}; foreach ($r in $rows) { $byId[[int]$r.Id] = $r }
$open    = @($rows | Where-Object { $_.State -in 'New', 'Active' })
$done    = @($rows | Where-Object { $_.State -in 'Resolved', 'Closed' })
$dropped = @($rows | Where-Object { $_.State -eq 'Removed' })
$epics   = @($rows | Where-Object { $_.Type -eq 'Epic' } | Sort-Object Id)

function Resolve-Epic {
    param($Row)
    $cursor = $Row
    $guard  = 0
    while ($cursor -and $cursor.Type -ne 'Epic' -and $guard -lt 10) {
        if (-not $cursor.Parent -or -not $byId.ContainsKey([int]$cursor.Parent)) { return $null }
        $cursor = $byId[[int]$cursor.Parent]
        $guard++
    }
    if ($cursor -and $cursor.Type -eq 'Epic') { return $cursor }
    return $null
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
$md = @()
$md += '---'
$md += 'description: Generated view of every Azure Scout work item, built from the live Azure DevOps board and GitHub issues.'
$md += '---'
$md += ''
$md += '# Azure Scout — Complete Task List'
$md += ''
$md += '::: warning Generated file'
$md += 'Do not edit this page by hand. Azure DevOps and GitHub are the source of truth; this page is'
$md += 'a rendering of them. Regenerate it with `./scripts/Build-TaskList.ps1`.'
$md += ':::'
$md += ''
$md += "Generated **$stamp UTC** from ADO project ``$ProjectId`` and ``$Repository``."
$md += ''
$md += '## Summary'
$md += ''
$md += '| Measure | Count |'
$md += '|---|---|'
$md += "| Work items | $($rows.Count) |"
foreach ($g in ($rows | Group-Object State | Sort-Object Name)) { $md += "| State: $($g.Name) | $($g.Count) |" }
foreach ($g in ($rows | Group-Object Type  | Sort-Object Name)) { $md += "| Type: $($g.Name) | $($g.Count) |" }
$md += "| Linked GitHub issues | $(@($rows | ForEach-Object { $_.Github } | Where-Object { $_ } | Sort-Object -Unique).Count) |"
$md += ''

$md += '## Open work'
$md += ''
if (-not $open) {
    $md += '_Nothing is open. Every work item on the board is delivered or dropped._'
    $md += ''
} else {
    foreach ($epic in $epics) {
        $children = @($open | Where-Object { $_.Id -ne $epic.Id -and (Resolve-Epic $_) -and (Resolve-Epic $_).Id -eq $epic.Id })
        $self     = @($open | Where-Object { $_.Id -eq $epic.Id })
        if (-not $children -and -not $self) { continue }
        $md += "### AB#$($epic.Id) — $(Format-Title $epic.Title)"
        $md += ''
        $md += Format-ItemTable -Rows (@($self) + @($children)) -GhState $ghState -Repo $Repository
    }
    $orphans = @($open | Where-Object { $_.Type -ne 'Epic' -and -not (Resolve-Epic $_) })
    if ($orphans) {
        $md += '### Not under an epic'
        $md += ''
        $md += Format-ItemTable -Rows $orphans -GhState $ghState -Repo $Repository
    }
}

$md += '## Delivered'
$md += ''
foreach ($epic in $epics) {
    $children = @($done | Where-Object { $_.Id -ne $epic.Id -and (Resolve-Epic $_) -and (Resolve-Epic $_).Id -eq $epic.Id })
    $self     = @($done | Where-Object { $_.Id -eq $epic.Id })
    if (-not $children -and -not $self) { continue }
    $md += "### AB#$($epic.Id) — $(Format-Title $epic.Title)"
    $md += ''
    $md += Format-ItemTable -Rows (@($self) + @($children)) -GhState $ghState -Repo $Repository
}
$doneOrphans = @($done | Where-Object { $_.Type -ne 'Epic' -and -not (Resolve-Epic $_) })
if ($doneOrphans) {
    $md += '### Not under an epic'
    $md += ''
    $md += Format-ItemTable -Rows $doneOrphans -GhState $ghState -Repo $Repository
}

if ($dropped) {
    $md += '## Dropped'
    $md += ''
    $md += Format-ItemTable -Rows $dropped -GhState $ghState -Repo $Repository
}

$resolved = [System.IO.Path]::GetFullPath($OutputPath)
Set-Content -Path $resolved -Value ($md -join "`n") -Encoding utf8
Write-Output "Wrote $($md.Count) lines to $resolved ($($rows.Count) work items, $($open.Count) open)."

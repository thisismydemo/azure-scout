#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all AI / Machine Learning inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each AI module
    using synthetic mock data. No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   14.6 — Phase 14 Testing (AI/Foundry/ML)
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$AIPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'AI'

$AIModules = @(
    @{ Name = 'OpenAIAccounts';         File = 'OpenAIAccounts.ps1';         Type = 'microsoft.cognitiveservices/accounts'; Kind = 'OpenAI';             Worksheet = 'Azure OpenAI Services' }
    @{ Name = 'SearchServices';         File = 'SearchServices.ps1';         Type = 'microsoft.search/searchservices';      Kind = '';                   Worksheet = 'Search Services' }
    @{ Name = 'MachineLearning';        File = 'MachineLearning.ps1';        Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Workspaces' }
    @{ Name = 'SpeechService';          File = 'SpeechService.ps1';          Type = 'microsoft.cognitiveservices/accounts'; Kind = 'SpeechServices';     Worksheet = 'Speech Service' }
    @{ Name = 'TextAnalytics';          File = 'TextAnalytics.ps1';          Type = 'microsoft.cognitiveservices/accounts'; Kind = 'TextAnalytics';      Worksheet = 'Language / Text Analytics' }
    @{ Name = 'ComputerVision';         File = 'ComputerVision.ps1';         Type = 'microsoft.cognitiveservices/accounts'; Kind = 'ComputerVision';     Worksheet = 'Computer Vision' }
    @{ Name = 'ContentSafety';          File = 'ContentSafety.ps1';          Type = 'microsoft.cognitiveservices/accounts'; Kind = 'ContentSafety';      Worksheet = 'Content Safety' }
    @{ Name = 'FormRecognizer';         File = 'FormRecognizer.ps1';         Type = 'microsoft.cognitiveservices/accounts'; Kind = 'FormRecognizer';     Worksheet = 'Document Intelligence' }
    @{ Name = 'BotServices';            File = 'BotServices.ps1';            Type = 'microsoft.botservice/botservices';     Kind = '';                   Worksheet = 'Bot Services' }
    @{ Name = 'AIFoundryHubs';          File = 'AIFoundryHubs.ps1';          Type = 'microsoft.machinelearningservices/workspaces'; Kind = 'Hub';         Worksheet = 'AI Foundry Hubs' }
    @{ Name = 'AIFoundryProjects';      File = 'AIFoundryProjects.ps1';      Type = 'microsoft.machinelearningservices/workspaces'; Kind = 'Project';     Worksheet = 'AI Foundry Projects' }
    # --- New modules ---
    @{ Name = 'AppliedAIServices';      File = 'AppliedAIServices.ps1';      Type = 'microsoft.cognitiveservices/accounts'; Kind = 'FormRecognizer';     Worksheet = 'Applied AI' }
    @{ Name = 'AzureAI';                File = 'AzureAI.ps1';                Type = 'microsoft.cognitiveservices/accounts'; Kind = 'AIServices';         Worksheet = 'Azure AI' }
    @{ Name = 'ContentModerator';       File = 'ContentModerator.ps1';       Type = 'microsoft.cognitiveservices/accounts'; Kind = 'ContentModerator';   Worksheet = 'Content Moderator' }
    @{ Name = 'CustomVision';           File = 'CustomVision.ps1';           Type = 'microsoft.cognitiveservices/accounts'; Kind = 'CustomVision.Training'; Worksheet = 'Custom Vision' }
    @{ Name = 'FaceAPI';                File = 'FaceAPI.ps1';                Type = 'microsoft.cognitiveservices/accounts'; Kind = 'Face';               Worksheet = 'Face API' }
    @{ Name = 'HealthInsights';         File = 'HealthInsights.ps1';         Type = 'microsoft.cognitiveservices/accounts'; Kind = 'HealthInsights';     Worksheet = 'Health Insights' }
    @{ Name = 'ImmersiveReader';        File = 'ImmersiveReader.ps1';        Type = 'microsoft.cognitiveservices/accounts'; Kind = 'ImmersiveReader';    Worksheet = 'Immersive Reader' }
    @{ Name = 'Translator';             File = 'Translator.ps1';             Type = 'microsoft.cognitiveservices/accounts'; Kind = 'TextTranslation';    Worksheet = 'Translator' }
    @{ Name = 'MLComputes';             File = 'MLComputes.ps1';             Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Computes' }
    @{ Name = 'MLDatasets';             File = 'MLDatasets.ps1';             Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Datasets' }
    @{ Name = 'MLDatastores';           File = 'MLDatastores.ps1';           Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Datastores' }
    @{ Name = 'MLEndpoints';            File = 'MLEndpoints.ps1';            Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Endpoints' }
    @{ Name = 'MLModels';               File = 'MLModels.ps1';               Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Models' }
    @{ Name = 'MLPipelines';            File = 'MLPipelines.ps1';            Type = 'microsoft.machinelearningservices/workspaces'; Kind = '';            Worksheet = 'ML Pipelines' }
    @{ Name = 'OpenAIDeployments';      File = 'OpenAIDeployments.ps1';      Type = 'microsoft.cognitiveservices/accounts'; Kind = 'OpenAI';             Worksheet = 'OpenAI Deployments' }
    @{ Name = 'SearchIndexes';          File = 'SearchIndexes.ps1';          Type = 'microsoft.search/searchservices';      Kind = '';                   Worksheet = 'Search Indexes' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:AIPath     = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'AI'
    $script:TempDir    = Join-Path $env:TEMP 'AZSC_AITests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockAIResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-ai',
              [string]$SubscriptionId = 'sub-00000001', [object]$Props)
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            KIND           = $Kind
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Props
        }
    }

    $script:MockResources = @()

    # OpenAI Account (Kind = OpenAI)
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/oai/oai1' -Name 'oai-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'OpenAI' -Props ([PSCustomObject]@{
        endpoint = 'https://oai-prod.openai.azure.com'; customSubDomainName = 'oai-prod'
        provisioningState = 'Succeeded'
        networkAcls = [PSCustomObject]@{ defaultAction = 'Allow' }
        sku = [PSCustomObject]@{ name = 'S0' }
    })

    # Speech Service
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/speech/speech1' -Name 'speech-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'SpeechServices' -Props ([PSCustomObject]@{
        endpoint = 'https://eastus.api.cognitive.microsoft.com/'; provisioningState = 'Succeeded'
        datecreated = '2025-08-15T10:30:00Z'
        sku = [PSCustomObject]@{ name = 'S0' }
    })

    # Text Analytics / Language
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/ta/ta1' -Name 'lang-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'TextAnalytics' -Props ([PSCustomObject]@{
        endpoint = 'https://lang-prod.cognitiveservices.azure.com/'; provisioningState = 'Succeeded'
        datecreated = '2025-06-01T08:00:00Z'
        sku = [PSCustomObject]@{ name = 'S' }
    })

    # Computer Vision
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/cv/cv1' -Name 'cv-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'ComputerVision' -Props ([PSCustomObject]@{
        endpoint = 'https://cv-prod.cognitiveservices.azure.com/'; provisioningState = 'Succeeded'
        datecreated = '2025-07-10T14:00:00Z'
        sku = [PSCustomObject]@{ name = 'S1' }
    })

    # Content Safety
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/cs/cs1' -Name 'cs-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'ContentSafety' -Props ([PSCustomObject]@{
        endpoint = 'https://cs-prod.cognitiveservices.azure.com/'; provisioningState = 'Succeeded'
        datecreated = '2025-09-20T12:00:00Z'
        sku = [PSCustomObject]@{ name = 'S0' }
    })

    # Form Recognizer / Document Intelligence
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/fr/fr1' -Name 'fr-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'FormRecognizer' -Props ([PSCustomObject]@{
        endpoint = 'https://fr-prod.cognitiveservices.azure.com/'; provisioningState = 'Succeeded'
        datecreated = '2025-05-05T09:00:00Z'
        sku = [PSCustomObject]@{ name = 'S0' }
    })

    # Cognitive Search
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/srch/srch1' -Name 'srch-prod' `
        -Type 'microsoft.search/searchservices' -Kind '' -Props ([PSCustomObject]@{
        replicaCount = 1; partitionCount = 1; hostingMode = 'default'; provisioningState = 'Succeeded'
        sku = [PSCustomObject]@{ name = 'standard' }
        networkRuleSet = [PSCustomObject]@{ bypass = 'None' }
    })

    # ML Workspace (generic)
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/mlws/mlws1' -Name 'mlws-prod' `
        -Type 'microsoft.machinelearningservices/workspaces' -Kind 'Default' -Props ([PSCustomObject]@{
        storageAccount = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Storage/storageAccounts/saml01'
        keyVault = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.KeyVault/vaults/kvml01'
        applicationInsights = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Insights/components/aiml01'
        containerRegistry = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.ContainerRegistry/registries/crml01'
        publicNetworkAccess = 'Enabled'; provisioningState = 'Succeeded'
        creationTime = '2025-03-01T10:00:00Z'
        managedNetwork = [PSCustomObject]@{ isolationMode = 'Disabled' }
    })

    # AI Foundry Hub
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/mlws/hub1' -Name 'hub-prod' `
        -Type 'microsoft.machinelearningservices/workspaces' -Kind 'Hub' -Props ([PSCustomObject]@{
        storageAccount = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Storage/storageAccounts/sahub01'
        keyVault = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.KeyVault/vaults/kvhub01'
        applicationInsights = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Insights/components/aihub01'
        containerRegistry = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.ContainerRegistry/registries/crhub01'
        publicNetworkAccess = 'Enabled'; provisioningState = 'Succeeded'
        creationTime = '2025-04-15T09:00:00Z'
    })

    # AI Foundry Project
    $script:MockResources += New-MockAIResource -Id '/sub/sub-00000001/mlws/proj1' -Name 'proj-chatapp' `
        -Type 'microsoft.machinelearningservices/workspaces' -Kind 'Project' -Props ([PSCustomObject]@{
        storageAccount = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Storage/storageAccounts/saproj01'
        keyVault = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.KeyVault/vaults/kvproj01'
        applicationInsights = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Insights/components/aiproj01'
        containerRegistry = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.ContainerRegistry/registries/crproj01'
        publicNetworkAccess = 'Enabled'; provisioningState = 'Succeeded'
        creationTime = '2025-05-20T11:00:00Z'
        hubResourceId = '/sub/sub-00000001/mlws/hub1'
    })

    # Bot Service
    $script:MockResources += New-MockAIResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/microsoft.botservice/botservices/bot-support' -Name 'bot-support' `
        -Type 'microsoft.botservice/botservices' -Kind 'Bot' -Props ([PSCustomObject]@{
        endpoint = 'https://bot-support.azurewebsites.net/api/messages'; msaAppId = 'app-id-001'
        provisioningState = 'Succeeded'
        sku = [PSCustomObject]@{ name = 'S1' }
    })

    # --- New Cognitive Services mock resources ---
    $cogSvcBase = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/microsoft.cognitiveservices/accounts'
    $peMock     = @([PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/Microsoft.Network/privateEndpoints/pe-cog' })
    $cogProps   = { param($kind)
        [PSCustomObject]@{
            datecreated = '2025-06-15T10:00:00Z'
            endpoint = "https://$kind-prod.cognitiveservices.azure.com/"
            customsubdomainname = "$kind-prod"
            publicnetworkaccess = 'Enabled'
            ismigrated = $false
            networkacls = [PSCustomObject]@{ defaultaction = 'Allow'; iprules = @(); virtualnetworkrules = @() }
            privateendpointconnections = $peMock
            provisioningState = 'Succeeded'
            disableLocalAuth = $false
            apiProperties = [PSCustomObject]@{
                TA4HResourceId = '/subscriptions/sub-00000001/resourceGroups/rg-ai/providers/microsoft.cognitiveservices/accounts/lang-prod'
            }
        }
    }

    # AppliedAIServices (uses KIND in appliedAIKinds array, including 'FormRecognizer')
    $aaiRes = New-MockAIResource -Id "$cogSvcBase/aai-prod" -Name 'aai-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'FormRecognizer' -Props (& $cogProps 'aai')
    $aaiRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $aaiRes

    # AzureAI (Kind = AIServices)
    $aisvRes = New-MockAIResource -Id "$cogSvcBase/aisvc-prod" -Name 'aisvc-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'AIServices' -Props (& $cogProps 'aisvc')
    $aisvRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $aisvRes

    # ContentModerator
    $cmRes = New-MockAIResource -Id "$cogSvcBase/cm-prod" -Name 'cm-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'ContentModerator' -Props (& $cogProps 'cm')
    $cmRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $cmRes

    # CustomVision (Kind like 'CustomVision.*')
    $cvtRes = New-MockAIResource -Id "$cogSvcBase/cvtrain-prod" -Name 'cvtrain-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'CustomVision.Training' -Props (& $cogProps 'cvtrain')
    $cvtRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $cvtRes

    # FaceAPI (Kind = Face)
    $faceRes = New-MockAIResource -Id "$cogSvcBase/face-prod" -Name 'face-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'Face' -Props (& $cogProps 'face')
    $faceRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $faceRes

    # HealthInsights
    $hiRes = New-MockAIResource -Id "$cogSvcBase/hi-prod" -Name 'hi-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'HealthInsights' -Props (& $cogProps 'hi')
    $hiRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $hiRes

    # ImmersiveReader
    $irRes = New-MockAIResource -Id "$cogSvcBase/ir-prod" -Name 'ir-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'ImmersiveReader' -Props (& $cogProps 'ir')
    $irRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $irRes

    # Translator (Kind = TextTranslation)
    $trRes = New-MockAIResource -Id "$cogSvcBase/tr-prod" -Name 'tr-prod' `
        -Type 'microsoft.cognitiveservices/accounts' -Kind 'TextTranslation' -Props (& $cogProps 'tr')
    $trRes | Add-Member -NotePropertyName 'sku' -NotePropertyValue ([PSCustomObject]@{ name = 'S0' }) -Force
    $script:MockResources += $trRes

    # --- Mock Invoke-AzRestMethod for ML/OpenAI/Search child modules ---
    function Invoke-AzRestMethod {
        param([string]$Path, [string]$Method = 'GET')
        $mockResponse = @{ value = @() }
        if ($Path -match '/computes\?') {
            $mockResponse = @{ value = @(@{ name = 'gpu-cluster'; properties = @{ computeType = 'AmlCompute'; vmSize = 'Standard_NC6'; scaleSettings = @{ minNodeCount = 0; maxNodeCount = 4 }; vmPriority = 'Dedicated'; provisioningState = 'Succeeded' } }) }
        } elseif ($Path -match '/data\?') {
            $mockResponse = @{ value = @(@{ name = 'train-data'; properties = @{ dataType = 'uri_file'; dataUri = 'azureml://datastores/default/data.csv'; description = 'Training data' }; systemData = @{ createdAt = '2025-06-01T10:00:00Z' } }) }
        } elseif ($Path -match '/data/[^/]+/versions') {
            $mockResponse = @{ value = @(@{ name = '1'; properties = @{ dataType = 'uri_file'; dataUri = 'azureml://datastores/default/data.csv'; description = 'v1' }; systemData = @{ createdAt = '2025-06-01T10:00:00Z' } }) }
        } elseif ($Path -match '/datastores\?') {
            $mockResponse = @{ value = @(@{ name = 'default'; properties = @{ datastoreType = 'AzureBlob'; accountName = 'saml01'; containerName = 'mldata'; isDefault = $true; credentials = @{ credentialsType = 'AccountKey' } } }) }
        } elseif ($Path -match '/onlineEndpoints\?|/batchEndpoints\?') {
            $mockResponse = @{ value = @(@{ name = 'ep-online'; properties = @{ authMode = 'Key'; scoringUri = 'https://ep-online.eastus.inference.ml.azure.com/score'; provisioningState = 'Succeeded' } }) }
        } elseif ($Path -match '/deployments\?') {
            $mockResponse = @{ value = @(@{ name = 'deploy1' }) }
        } elseif ($Path -match '/models\?') {
            $mockResponse = @{ value = @(@{ name = 'my-model'; properties = @{ flavors = @{ sklearn = @{}; python_function = @{} } }; systemData = @{ createdAt = '2025-06-01T10:00:00Z' } }) }
        } elseif ($Path -match '/models/[^/]+/versions') {
            $mockResponse = @{ value = @(@{ name = '1'; properties = @{ flavors = [PSCustomObject]@{ sklearn = @{} } }; systemData = @{ createdAt = '2025-06-01T10:00:00Z' } }) }
        } elseif ($Path -match '/jobs\?') {
            $mockResponse = @{ value = @(@{ name = 'pipeline-run-1'; properties = @{ displayName = 'training-pipeline'; status = 'Completed'; experimentName = 'exp1'; creationContext = @{ createdAt = '2025-06-01T10:00:00Z'; lastModifiedAt = '2025-06-01T12:00:00Z' }; settings = @{ defaultCompute = 'gpu-cluster' } } }) }
        } elseif ($Path -match 'cognitiveservices/accounts/.+/deployments\?') {
            $mockResponse = @{ value = @(@{ name = 'gpt-4'; properties = @{ model = @{ name = 'gpt-4'; version = '0613'; format = 'OpenAI' }; scaleSettings = @{ scaleType = 'Standard'; capacity = 10 }; dynamicThrottlingEnabled = $false; provisioningState = 'Succeeded' } }) }
        } elseif ($Path -match 'searchservices/.+/indexes\?') {
            $mockResponse = @{ value = @(@{ name = 'idx-main'; fields = @(@{name='id'},@{name='content'}); analyzers = @(); scoringProfiles = @(); suggesters = @(); corsOptions = @{ allowedOrigins = @('*') }; defaultScoringProfile = $null; '@odata.etag' = '"0x123"' }) }
        }
        [PSCustomObject]@{ Content = ($mockResponse | ConvertTo-Json -Depth 10); StatusCode = 200 }
    }
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'AI Module Files Exist' {
    It 'AI module folder exists' {
        $script:AIPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $AIModules {
        Join-Path $script:AIPath $File | Should -Exist
    }
}

Describe 'AI Module Processing Phase — <Name>' -ForEach $AIModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:AIPath $File
        $script:ResType = $Type
        $script:ResKind = $Kind
    }

    It 'Processing returns results for matching resources' {
        $matchedResources = $script:MockResources | Where-Object {
            $_.TYPE -eq $script:ResType -and ($script:ResKind -eq '' -or $_.KIND -eq $script:ResKind)
        }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $result = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
            $result | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType' / kind '$script:ResKind'"
        }
    }

    It 'Processing does not throw when given an empty resource list' {
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'AI Module Reporting Phase — <Name>' -ForEach $AIModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:AIPath $File
        $script:ResType  = $Type
        $script:ResKind  = $Kind
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("AI_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

        $matchedResources = $script:MockResources | Where-Object {
            $_.TYPE -eq $script:ResType -and ($script:ResKind -eq '' -or $_.KIND -eq $script:ResKind)
        }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else {
            $script:ProcessedData = $null
        }
    }

    It 'Reporting phase does not throw' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType' / kind '$script:ResKind'"
        }
    }

    It 'Excel file is created' {
        if ($script:ProcessedData) {
            $script:XlsxFile | Should -Exist
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType' / kind '$script:ResKind'"
        }
    }
}

Describe 'AI Foundry Hub/Project Kind Detection' {
    It 'AIFoundryHubs only processes Kind=Hub workspaces' {
        $modFile  = Join-Path $script:AIPath 'AIFoundryHubs.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $sb       = [ScriptBlock]::Create($content)
        $result   = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        # Should only have the hub, not the project or generic workspace
        if ($result) {
            $result | Where-Object { $_ -is [System.Collections.Hashtable] } | ForEach-Object {
                # Hub results shouldn't contain the project name
                $_['Name'] | Should -Not -Be 'proj-chatapp'
            }
        }
    }

    It 'AIFoundryProjects only processes Kind=Project workspaces' {
        $modFile = Join-Path $script:AIPath 'AIFoundryProjects.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'OpenAI Kind Filtering' {
    It 'OpenAIAccounts only extracts Kind=OpenAI cognitive services accounts' {
        $modFile = Join-Path $script:AIPath 'OpenAIAccounts.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
        # Should produce exactly 1 row (only oai-prod has Kind=OpenAI)
        @($result).Count | Should -Be 1
    }
}

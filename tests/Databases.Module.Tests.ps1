#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Databases inventory modules.
.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
#>

$DatabasesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Databases'

$DatabaseModules = @(
    @{ Name = 'CosmosDB';         File = 'CosmosDB.ps1';         Type = 'microsoft.documentdb/databaseaccounts';              Worksheet = 'Cosmos DB' }
    @{ Name = 'MariaDB';          File = 'MariaDB.ps1';          Type = 'microsoft.dbformariadb/servers';                      Worksheet = 'MariaDB' }
    @{ Name = 'MySQL';            File = 'MySQL.ps1';            Type = 'microsoft.dbformysql/servers';                        Worksheet = 'MySQL' }
    @{ Name = 'MySQLflexible';    File = 'MySQLflexible.ps1';    Type = 'Microsoft.DBforMySQL/flexibleServers';                Worksheet = 'MySQL Flexible' }
    @{ Name = 'POSTGRE';          File = 'POSTGRE.ps1';          Type = 'microsoft.dbforpostgresql/servers';                   Worksheet = 'PostgreSQL' }
    @{ Name = 'POSTGREFlexible';  File = 'POSTGREFlexible.ps1';  Type = 'Microsoft.DBforPostgreSQL/flexibleServers';           Worksheet = 'PostgreSQL Flexible' }
    @{ Name = 'RedisCache';       File = 'RedisCache.ps1';       Type = 'microsoft.cache/redis';                               Worksheet = 'Redis Cache' }
    @{ Name = 'SQLDB';            File = 'SQLDB.ps1';            Type = 'microsoft.sql/servers/databases';                     Worksheet = 'SQL DBs' }
    @{ Name = 'SQLMI';            File = 'SQLMI.ps1';            Type = 'microsoft.sql/managedInstances';                      Worksheet = 'SQL MI' }
    @{ Name = 'SQLMIDB';          File = 'SQLMIDB.ps1';          Type = 'microsoft.sql/managedinstances/databases';            Worksheet = 'SQL MI DBs' }
    @{ Name = 'SQLPOOL';          File = 'SQLPOOL.ps1';          Type = 'microsoft.sql/servers/elasticPools';                  Worksheet = 'SQL Pools' }
    @{ Name = 'SQLSERVER';        File = 'SQLSERVER.ps1';        Type = 'microsoft.sql/servers';                               Worksheet = 'SQL Servers' }
    @{ Name = 'SQLVM';            File = 'SQLVM.ps1';            Type = 'microsoft.sqlvirtualmachine/sqlvirtualmachines';      Worksheet = 'SQL VMs' }
)

BeforeAll {
    $script:ModuleRoot    = Split-Path -Parent $PSScriptRoot
    $script:DatabasesPath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Databases'
    $script:TempDir       = Join-Path $env:TEMP 'AZSC_DatabasesTests'
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockDBResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-databases',
              [string]$SubscriptionId = 'sub-00000001', [object]$Props,
              [object]$SKU = $null, [object]$Sku2 = $null, $Zones = @('1'),
              $PrivateEndpointConnections = $null)
        # Use the lowercase 'sku' form when Sku2 is provided (SQLMI, SQLPOOL etc. use $1.sku)
        $skuVal = if ($Sku2) { $Sku2 } else { $SKU }
        $res = [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            KIND           = $Kind
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            tags           = [PSCustomObject]@{ env = 'test' }
            PROPERTIES     = $Props
            SKU            = $skuVal
            ZONES          = $Zones
        }
        # Add lowercase aliases via Add-Member so modules that access $1.sku / $1.zones / $1.kind work
        $res | Add-Member -NotePropertyName 'kind' -NotePropertyValue $Kind -Force
        $res | Add-Member -NotePropertyName 'zones' -NotePropertyValue $Zones -Force
        if ($PrivateEndpointConnections) {
            $res | Add-Member -NotePropertyName 'privateEndpointConnections' -NotePropertyValue $PrivateEndpointConnections -Force
        }
        return $res
    }

    $script:MockResources = @()

    # --- CosmosDB ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.documentdb/databaseaccounts/cosmos-prod' `
        -Name 'cosmos-prod' -Type 'microsoft.documentdb/databaseaccounts' `
        -Props ([PSCustomObject]@{
            virtualNetworkRules = @([PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-cosmos/subnets/cosmos-subnet' })
            privateEndpointConnections = @([PSCustomObject]@{ Id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-cosmos' })
            failoverPolicies = @(
                [PSCustomObject]@{ locationName = 'East US'; failoverPriority = 0 }
                [PSCustomObject]@{ locationName = 'West US'; failoverPriority = 1 }
            )
            mongoEndpoint = $null
            documentEndpoint = 'https://cosmos-prod.documents.azure.com:443/'
            enableFreeTier = $false
            EnabledApiTypes = 'Sql'
            backupPolicy = [PSCustomObject]@{
                type = 'Periodic'
                periodicModeProperties = [PSCustomObject]@{ backupStorageRedundancy = 'Geo' }
            }
            databaseAccountOfferType = 'Standard'
            isVirtualNetworkFilterEnabled = $true
            capapcity = [PSCustomObject]@{ totalthroughputlimit = 4000 }
            capabilities = @([PSCustomObject]@{ Name = 'EnableServerless' })
            publicNetworkAccess = 'Enabled'
            consistencyPolicy = [PSCustomObject]@{ defaultConsistencyLevel = 'Session' }
            readLocations = @([PSCustomObject]@{ locationName = 'East US' })
            writeLocations = @([PSCustomObject]@{ locationName = 'East US' })
            cors = @()
        })

    # --- MariaDB ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.dbformariadb/servers/mariadb-prod' `
        -Name 'mariadb-prod' -Type 'microsoft.dbformariadb/servers' `
        -SKU ([PSCustomObject]@{ name = 'GP_Gen5_2'; family = 'Gen5'; tier = 'GeneralPurpose'; capacity = 2 }) `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{ Id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-mariadb' })
            version = '10.3'
            storageProfile = [PSCustomObject]@{ backupRetentionDays = 7; geoRedundantBackup = 'Disabled'; storageAutogrow = 'Enabled'; storageMB = 51200 }
            publicNetworkAccess = 'Enabled'
            administratorLogin = 'dbadmin'
            InfrastructureEncryption = 'Disabled'
            minimalTlsVersion = 'TLS1_2'
            userVisibleState = 'Ready'
            replicaCapacity = 5
            replicationRole = 'None'
            byokEnforcement = 'Disabled'
            sslEnforcement = 'Enabled'
        })

    # --- MySQL ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.dbformysql/servers/mysql-prod' `
        -Name 'mysql-prod' -Type 'microsoft.dbformysql/servers' `
        -SKU ([PSCustomObject]@{ name = 'GP_Gen5_4'; family = 'Gen5'; tier = 'GeneralPurpose'; capacity = 4 }) `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{ Id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-mysql' })
            version = '5.7'
            storageProfile = [PSCustomObject]@{ backupRetentionDays = 14; geoRedundantBackup = 'Enabled'; storageAutogrow = 'Enabled'; storageMB = 102400 }
            publicNetworkAccess = 'Disabled'
            administratorLogin = 'mysqladmin'
            InfrastructureEncryption = 'Enabled'
            minimalTlsVersion = 'TLS1_2'
            userVisibleState = 'Ready'
            replicaCapacity = 5
            replicationRole = 'None'
            byokEnforcement = 'Disabled'
            sslEnforcement = 'Enabled'
        })

    # --- MySQL Flexible ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.DBforMySQL/flexibleServers/mysql-flex-prod' `
        -Name 'mysql-flex-prod' -Type 'Microsoft.DBforMySQL/flexibleServers' `
        -Props ([PSCustomObject]@{
            sku = [PSCustomObject]@{ name = 'Standard_D2ds_v4' }
            version = '8.0'
            state = 'Ready'
            availabilityZone = '1'
            administratorLogin = 'flexadmin'
            storage = [PSCustomObject]@{ storageSizeGB = 128; iops = 360; autoGrow = 'Enabled'; storageSku = 'Premium_LRS' }
            maintenanceWindow = [PSCustomObject]@{ customWindow = 'Enabled' }
            replicationRole = 'None'
            replicaCapacity = 10
            network = [PSCustomObject]@{ publicNetworkAccess = 'Disabled' }
            backup = [PSCustomObject]@{ backupRetentionDays = 7; geoRedundantBackup = 'Disabled' }
            highAvailability = [PSCustomObject]@{ mode = 'ZoneRedundant'; state = 'Healthy' }
            fullyQualifiedDomainName = 'mysql-flex-prod.mysql.database.azure.com'
        })

    # --- PostgreSQL ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.dbforpostgresql/servers/pg-prod' `
        -Name 'pg-prod' -Type 'microsoft.dbforpostgresql/servers' `
        -SKU ([PSCustomObject]@{ name = 'GP_Gen5_8'; family = 'Gen5'; tier = 'GeneralPurpose'; capacity = 8 }) `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{ Id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-pg' })
            version = '11'
            storageProfile = [PSCustomObject]@{ backupRetentionDays = 14; geoRedundantBackup = 'Enabled'; storageAutogrow = 'Enabled'; storageMB = 204800 }
            publicNetworkAccess = 'Disabled'
            administratorLogin = 'pgadmin'
            InfrastructureEncryption = 'Enabled'
            minimalTlsVersion = 'TLS1_2'
            userVisibleState = 'Ready'
            replicaCapacity = 5
            replicationRole = 'None'
            byokEnforcement = 'Disabled'
            sslEnforcement = 'Enabled'
        })

    # --- PostgreSQL Flexible ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-flex-prod' `
        -Name 'pg-flex-prod' -Type 'Microsoft.DBforPostgreSQL/flexibleServers' `
        -SKU ([PSCustomObject]@{ tier = 'GeneralPurpose'; name = 'Standard_D4s_v3' }) `
        -Props ([PSCustomObject]@{
            fullyqualifieddomainname = 'pg-flex-prod.postgres.database.azure.com'
            administratorLogin = 'pgflexadmin'
            version = '15'
            minorversion = '4'
            authconfig = [PSCustomObject]@{ activedirectoryauth = 'Enabled'; passwordauth = 'Enabled' }
            storage = [PSCustomObject]@{ storagesizegb = 256 }
            availabilityzone = '2'
            highavailability = [PSCustomObject]@{ state = 'Healthy' }
            dataencryption = [PSCustomObject]@{ type = 'SystemManaged' }
            backup = [PSCustomObject]@{ backupretentiondays = 7; geoRedundantBackup = 'Disabled' }
            replicationRole = 'Primary'
            replicaCapacity = 5
            network = [PSCustomObject]@{
                publicnetworkaccess = 'Disabled'
                delegatedsubnetresourceid = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-pg/subnets/pg-subnet'
                privatednszonearmresourceid = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/privateDnsZones/pg.postgres.database.azure.com'
            }
        })

    # --- Redis Cache (standard) ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.cache/redis/redis-prod' `
        -Name 'redis-prod' -Type 'microsoft.cache/redis' `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{
                properties = [PSCustomObject]@{
                    privateEndpoint = [PSCustomObject]@{
                        id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-redis'
                    }
                }
            })
            redisVersion = '6.0'
            publicNetworkAccess = 'Disabled'
            hostName = 'redis-prod.redis.cache.windows.net'
            port = 6379
            enableNonSslPort = $false
            minimumTlsVersion = '1.2'
            sslPort = 6380
            sku = [PSCustomObject]@{ name = 'Premium'; capacity = 1; family = 'P' }
            redisConfiguration = [PSCustomObject]@{
                'maxfragmentationmemory-reserved' = '642'
                'maxmemory-reserved' = '642'
                'maxmemory-delta' = '642'
                'maxclients' = '7500'
            }
        })

    # --- Redis Enterprise ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.cache/redisenterprise/redis-ent-prod' `
        -Name 'redis-ent-prod' -Type 'microsoft.cache/redisenterprise' `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @()
            redisVersion = '6.0'
            publicNetworkAccess = 'Enabled'
            hostName = 'redis-ent-prod.redisenterprise.cache.azure.net'
            port = 10000
            enableNonSslPort = $false
            minimumTlsVersion = ''
            sslPort = 10000
            sku = [PSCustomObject]@{ name = 'Enterprise_E10'; capacity = 2; family = 'Enterprise' }
            redisConfiguration = [PSCustomObject]@{
                'maxfragmentationmemory-reserved' = $null
                'maxmemory-reserved' = $null
                'maxmemory-delta' = $null
                'maxclients' = $null
            }
        })

    # --- SQL Database (non-master) ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sql/servers/sql-prod/databases/appdb' `
        -Name 'appdb' -Type 'microsoft.sql/servers/databases' `
        -Props ([PSCustomObject]@{
            elasticPoolId = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Sql/servers/sql-prod/elasticPools/ep-prod'
            earliestrestoredate = '2025-06-01T00:00:00Z'
            defaultSecondaryLocation = 'westus'
            status = 'Online'
            availabilityzone = '1'
            minCapacity = 0.5
            currentSku = [PSCustomObject]@{ capacity = 2; tier = 'GeneralPurpose'; name = 'GP_S_Gen5' }
            zoneRedundant = $false
            catalogCollation = 'SQL_Latin1_General_CP1_CI_AS'
            readReplicaCount = 0
            maxSizeBytes = 34359738368
        })

    # --- SQL Managed Instance ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sql/managedInstances/sqlmi-prod' `
        -Name 'sqlmi-prod' -Type 'microsoft.sql/managedInstances' `
        -Sku2 ([PSCustomObject]@{ Name = 'GP_Gen5'; capacity = 8; tier = 'GeneralPurpose' }) `
        -PrivateEndpointConnections @([PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Network/privateEndpoints/pe-sqlmi' }) `
        -Props ([PSCustomObject]@{
            adminitrators = [PSCustomObject]@{ login = 'sqladmin'; azureADOnlyAuthentication = $false }
            fullyQualifiedDomainName = 'sqlmi-prod.abcdef123456.database.windows.net'
            publicDataEndpointEnabled = $false
            licenseType = 'LicenseIncluded'
            managedInstanceCreateMode = 'Default'
            zoneRedundant = $true
        })

    # --- SQL MI Database ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sql/managedinstances/sqlmi-prod/databases/midb-app' `
        -Name 'midb-app' -Type 'microsoft.sql/managedinstances/databases' `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Sql/managedInstances/sqlmi-prod/privateEndpoints/pe-midb' })
            collation = 'SQL_Latin1_General_CP1_CI_AS'
            creationDate = '2025-03-15T10:00:00Z'
            defaultSecondaryLocation = 'westus'
            status = 'Online'
        })

    # --- SQL Elastic Pool ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sql/servers/sql-prod/elasticPools/ep-prod' `
        -Name 'ep-prod' -Type 'microsoft.sql/servers/elasticPools' `
        -Sku2 ([PSCustomObject]@{ capacity = 200; name = 'GP_Gen5'; tier = 'GeneralPurpose' }) `
        -Props ([PSCustomObject]@{
            state = 'Ready'
            licenseType = 'LicenseIncluded'
            maxSizeBytes = 107374182400
            perDatabaseSettings = [PSCustomObject]@{ maxCapacity = 2; minCapacity = 0 }
            zoneRedundant = $false
        })

    # --- SQL Server ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sql/servers/sql-prod' `
        -Name 'sql-prod' -Type 'microsoft.sql/servers' -Kind 'v12.0' `
        -Props ([PSCustomObject]@{
            privateEndpointConnections = @([PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/Microsoft.Sql/servers/sql-prod/privateEndpoints/pe-sqlserver' })
            administratorLogin = 'sqladmin'
            fullyQualifiedDomainName = 'sql-prod.database.windows.net'
            publicNetworkAccess = 'Disabled'
            minimalTlsVersion = '1.2'
            state = 'Ready'
            version = '12.0'
        })

    # --- SQL VM ---
    $script:MockResources += New-MockDBResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-databases/providers/microsoft.sqlvirtualmachine/sqlvirtualmachines/sqlvm-prod' `
        -Name 'sqlvm-prod' -Type 'microsoft.sqlvirtualmachine/sqlvirtualmachines' `
        -Props ([PSCustomObject]@{
            sqlServerLicenseType = 'PAYG'
            sqlImageOffer = 'SQL2019-WS2019'
            sqlManagement = 'Full'
            sqlImageSku = 'Enterprise'
        })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

Describe 'Databases Module Files Exist' {
    It 'Databases module folder exists' { $script:DatabasesPath | Should -Exist }
    It '<Name> module file exists' -ForEach $DatabaseModules { Join-Path $script:DatabasesPath $File | Should -Exist }
}

Describe 'Databases Module Processing Phase — <Name>' -ForEach $DatabaseModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:DatabasesPath $File
        $script:ResType = $Type
    }
    It 'Processing returns results when matching resources are present' {
        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $result = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
            $result | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }
    It 'Processing does not throw when given an empty resource list' {
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Databases Module Reporting Phase — <Name>' -ForEach $DatabaseModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:DatabasesPath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("DB_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else { $script:ProcessedData = $null }
    }
    It 'Reporting phase does not throw' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else { Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'" }
    }
    It 'Excel file is created' {
        if ($script:ProcessedData) { $script:XlsxFile | Should -Exist }
        else { Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'" }
    }
}

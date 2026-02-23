# Basic Usage

This guide covers the fundamental usage patterns for Azure Tenant Inventory (AZTI). For a quick start, see the [Quick Start Guide](../getting-started/quick-start.md).

## Command Structure

The basic syntax for AZTI is:

```powershell
Invoke-AzureTenantInventory [parameters]
```

## Authentication

AZTI supports multiple authentication methods:

### Interactive Login

```powershell
# AZTI will prompt for interactive login if not already authenticated
Invoke-AzureTenantInventory
```

### Specific Tenant

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000"
```

### Service Principal

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -AppId "00000000-0000-0000-0000-000000000000" -Secret "your-client-secret"
```

### Certificate-Based Authentication

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -AppId "00000000-0000-0000-0000-000000000000" -CertificatePath "C:\Certificates\cert.pfx"
```

### Device Code Authentication

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -DeviceLogin
```

## Scoping Your Inventory

AZTI can be scoped to different levels:

### All Accessible Resources

```powershell
Invoke-AzureTenantInventory
```

### Specific Subscription

```powershell
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000"
```

### Specific Resource Group

```powershell
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -ResourceGroup "MyResourceGroup"
```

### Management Group

```powershell
Invoke-AzureTenantInventory -ManagementGroup "MyManagementGroup"
```

### Tag-Based Filtering

```powershell
# Resources with specific tag key
Invoke-AzureTenantInventory -TagKey "Environment"

# Resources with specific tag value
Invoke-AzureTenantInventory -TagValue "Production"

# Resources with specific tag key and value
Invoke-AzureTenantInventory -TagKey "Environment" -TagValue "Production"
```

## Report Content Control

Control what information is included in your reports:

### Include Resource Tags

```powershell
Invoke-AzureTenantInventory -IncludeTags
```

### Include Security Center Data

```powershell
Invoke-AzureTenantInventory -SecurityCenter
```

### Skip Azure Policy Data

```powershell
Invoke-AzureTenantInventory -SkipPolicy
```

### Skip Azure VM Details

```powershell
Invoke-AzureTenantInventory -SkipVMDetails
```

### Skip Azure Advisory Collection

```powershell
Invoke-AzureTenantInventory -SkipAdvisory
```

### Include Cost Data

```powershell
# Note: Requires Az.CostManagement module
Invoke-AzureTenantInventory -IncludeCosts
```

## Report Output Options

Customize how the report is generated and saved:

### Custom Report Name

```powershell
Invoke-AzureTenantInventory -ReportName "MyAzureInventory"
```

### Custom Output Directory

```powershell
Invoke-AzureTenantInventory -ReportDir "C:\Reports"
```

### Lightweight Report Format

```powershell
# Generate report without charts for faster processing
Invoke-AzureTenantInventory -Lite
```

## Diagram Options

Control network diagram generation:

### Skip Diagram Creation

```powershell
Invoke-AzureTenantInventory -SkipDiagram
```

### Include All Network Components

```powershell
Invoke-AzureTenantInventory -DiagramFullEnvironment
```

## Other Common Options

Additional options to control AZTI behavior:

### Debug Mode

```powershell
# Run in debug mode for detailed logging
Invoke-AzureTenantInventory -Debug
```

### Prevent Automatic Updates

```powershell
# Skip automatic module updates
Invoke-AzureTenantInventory -NoAutoUpdate
```

### Specify Azure Environment

```powershell
# For non-standard Azure environments
Invoke-AzureTenantInventory -AzureEnvironment "AzureUSGovernment"
```

## Using Cloud Shell

When running in Azure Cloud Shell, it's recommended to use:

```powershell
Invoke-AzureTenantInventory -Debug
```

This helps to work around certain limitations in the Cloud Shell environment. 
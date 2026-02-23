# Parameters Reference

Azure Tenant Inventory (AZTI) offers a wide range of parameters to customize your inventory report generation. This page provides a comprehensive reference of all available parameters with detailed descriptions and examples.

## Core Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| **TenantID** | Specify the tenant ID for inventory | `-TenantID "00000000-0000-0000-0000-000000000000"` |
| **SubscriptionID** | Specify subscription(s) to inventory | `-SubscriptionID "00000000-0000-0000-0000-000000000000"` |
| **ResourceGroup** | Limit inventory to specific resource group(s) | `-ResourceGroup "MyResourceGroup"` |

## Authentication Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| **AppId** | Application ID for service principal auth | `-AppId "00000000-0000-0000-0000-000000000000"` |
| **Secret** | Secret for service principal authentication | `-Secret "your-client-secret"` |
| **CertificatePath** | Certificate path for service principal | `-CertificatePath "C:\certificates\cert.pfx"` |
| **DeviceLogin** | Use device login authentication | `-DeviceLogin` |

## Scope Control Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| **ManagementGroup** | Inventory all subscriptions in management group | `-ManagementGroup "MyManagementGroup"` |
| **TagKey** | Filter resources by tag key | `-TagKey "Environment"` |
| **TagValue** | Filter resources by tag value | `-TagValue "Production"` |

## Content Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| **SecurityCenter** | Include Security Center data | `-SecurityCenter` |
| **IncludeTags** | Include resource tags | `-IncludeTags` |
| **SkipPolicy** | Skip Azure Policy collection | `-SkipPolicy` |
| **SkipVMDetails** | Skip Azure VM Extra Details collection | `-SkipVMDetails` |
| **SkipAdvisory** | Skip Azure Advisory collection | `-SkipAdvisory` |
| **IncludeCosts** | Include Azure Cost details (requires Az.CostManagement) | `-IncludeCosts` |

## Output Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| **ReportName** | Custom report filename | `-ReportName "MyAzureInventory"` |
| **ReportDir** | Custom directory for report | `-ReportDir "C:\Reports"` |
| **Lite** | Use lightweight Excel generation (no charts) | `-Lite` |

## Diagram Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| **SkipDiagram** | Skip diagram creation | `-SkipDiagram` |
| **DiagramFullEnvironment** | Include all network components in diagram | `-DiagramFullEnvironment` |

## Other Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Debug** | Run in debug mode | `-Debug` |
| **NoAutoUpdate** | Skip the auto update of the AZTI Module | `-NoAutoUpdate` |
| **AzureEnvironment** | Specify Azure cloud environment | `-AzureEnvironment "AzureUSGovernment"` |
| **Automation** | Run using Automation Account | `-Automation` |
| **StorageAccount** | Storage account for automation output | `-StorageAccount "mystorageaccount"` |
| **StorageContainer** | Storage container for automation output | `-StorageContainer "reports"` |

## Examples of Parameter Combinations

### Basic Inventory with Tags

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -IncludeTags
```

### Scoped Inventory with Security Data

```powershell
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -SecurityCenter -ReportName "SecureInventory"
```

### Production Environment Inventory

```powershell
Invoke-AzureTenantInventory -TagKey "Environment" -TagValue "Production" -ReportDir "C:\Reports\Production"
```

### Management Group Inventory with Service Principal

```powershell
Invoke-AzureTenantInventory -ManagementGroup "MyMgmtGroup" -AppId "00000000-0000-0000-0000-000000000000" -Secret "your-client-secret"
```

### Lightweight Report without Diagrams

```powershell
Invoke-AzureTenantInventory -Lite -SkipDiagram
```

### Full Network Documentation

```powershell
Invoke-AzureTenantInventory -DiagramFullEnvironment
```

### Automation Account Execution

```powershell
Invoke-AzureTenantInventory -Automation -StorageAccount "mystorageaccount" -StorageContainer "reports"
``` 
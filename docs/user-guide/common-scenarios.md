# Common Scenarios

This guide covers common usage scenarios for Azure Tenant Inventory. Each scenario includes the required commands and explains when you might want to use each approach.

## Scenario 1: Complete Enterprise Documentation

When you need comprehensive documentation of your entire Azure estate across multiple subscriptions:

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -IncludeTags -SecurityCenter -IncludeCosts
```

This command will:
- Document all resources in the tenant
- Include all resource tags
- Include Security Center findings
- Include cost data for resources (requires Az.CostManagement module)

## Scenario 2: Quick Inventory for a Single Subscription

When you need a fast overview of a specific subscription:

```powershell
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -Lite -SkipDiagram
```

This command will:
- Document only the specified subscription
- Use lightweight reporting (no charts)
- Skip diagram generation for faster results

## Scenario 3: Security-Focused Documentation

When you need to assess the security posture of your Azure environment:

```powershell
Invoke-AzureTenantInventory -SecurityCenter -ReportName "SecurityInventory"
```

This command will:
- Include Azure Security Center findings
- Name the report "SecurityInventory"

## Scenario 4: Network Topology Documentation

When you need detailed network diagrams:

```powershell
Invoke-AzureTenantInventory -DiagramFullEnvironment -ReportName "NetworkDiagrams"
```

This command will:
- Generate comprehensive network diagrams
- Include all network components in the diagrams
- Name the report "NetworkDiagrams"

## Scenario 5: Production Environment Audit

When you need to focus on your production resources:

```powershell
Invoke-AzureTenantInventory -TagKey "Environment" -TagValue "Production" -IncludeTags
```

This command will:
- Document only resources tagged with "Environment:Production"
- Include all resource tags in the report

## Scenario 6: Regular Scheduled Reporting with Automation

When you need to set up regular reports using Azure Automation:

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -Automation -StorageAccount "mystorageaccount" -StorageContainer "reports"
```

This command will:
- Run in an Azure Automation Account
- Save reports to the specified storage account and container

See the [Automation Guide](../advanced/automation.md) for detailed setup instructions.

## Scenario 7: Non-Interactive Service Principal Access

When you need to run AZTI without interactive login:

```powershell
Invoke-AzureTenantInventory -TenantID "00000000-0000-0000-0000-000000000000" -AppId "00000000-0000-0000-0000-000000000000" -Secret "your-client-secret"
```

This command will:
- Use service principal authentication
- Require appropriate permissions for the service principal

## Scenario 8: Governance-Level Documentation with Policies

When you need to focus on governance and compliance:

```powershell
Invoke-AzureTenantInventory -ManagementGroup "governance-mg" -SkipDiagram
```

This command will:
- Document all resources within the specified management group
- Skip diagram generation to focus on resource details

## Scenario 9: Resource Group Comparison

When you need to compare development, staging, and production environments:

```powershell
# Run these separately to create three different reports
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -ResourceGroup "dev-rg" -ReportName "Dev-Inventory"
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -ResourceGroup "staging-rg" -ReportName "Staging-Inventory"
Invoke-AzureTenantInventory -SubscriptionID "00000000-0000-0000-0000-000000000000" -ResourceGroup "prod-rg" -ReportName "Prod-Inventory"
```

This set of commands will:
- Create separate inventory reports for each environment
- Allow side-by-side comparison of resources

## Scenario 10: Running in Cloud Shell

When you need to run AZTI in Azure Cloud Shell:

```powershell
Invoke-AzureTenantInventory -Debug -Lite -ReportName "CloudShellInventory"
```

This command will:
- Run in debug mode to handle Cloud Shell limitations
- Use lightweight reporting for better performance
- Name the report "CloudShellInventory" 
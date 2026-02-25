# Contributing to Azure Scout

<div align="center">
  <img src="images/AZSC_Logo.png" width="250">
  <h3>Guidelines for Community Contributions</h3>
  
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/thisismydemo/azure-scout/pulls)
  [![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
</div>

## Table of Contents

- [Getting Started](#getting-started)
- [Contribution Workflow](#contribution-workflow)
- [Development Guidelines](#development-guidelines)
- [Project Structure](#project-structure)
   - [Public Modules](#Public-Modules)
      - [PublicFunctions](#PublicFunctions)
      - [Diagram](#Diagram)
      - [Jobs](#Jobs)
   - [Private Modules](#Private-Modules)
      - [0.MainFunctions](#0.MainFunctions)
      - [1.ExtractionFunctions](#1.ExtractionFunctions)
         - [ResourceDetails](#1.ExtractionFunctions/ResourceDetails)
      - [2.ProcessingFunctions](#2.ProcessingFunctions)
      - [3.ReportingFunctions](#3.ReportingFunctions)
         - [StyleFunctions](#3.ReportingFunctions/StyleFunctions)
   - [Resource Types](#Resource-Types)
      - [Resource Type Modules](#Resource-Type-Modules)
      - [Resource Type Subfolders](#Resource-Type-Subfolders)
- [Getting Help](#getting-help)

## Getting Started

Thank you for considering contributing to Azure Scout (AZSC)! We welcome contributions from the community and are excited to see what you can bring to the project.

Before you begin, please familiarize yourself with the [README.md](README.md) file to understand the purpose and functionality of AZSC.

If you wish to contribute by adding a new Resource Type to AZSC, you may jump to the [Resource Types](#Resource-Types) section of this document.

## Contribution Workflow

Follow these steps to contribute to AZSC:

<table>
<tr>
<td width="60%">

1. **Fork the Repository**
   
   Start by forking the repository to your GitHub account using the "Fork" button at the top right of the repository page.

2. **Clone Your Fork**
   
   ```bash
   git clone https://github.com/your-username/AZSC.git
   cd AZSC
   ```

3. **Create a Branch**
   
   Create a new branch for your contribution:
   
   ```bash
   git checkout -b feature/your-feature-name
   ```
   
   Use a descriptive name that reflects your contribution.

4. **Make Your Changes**
   
   Implement your changes, ensuring they follow the [Development Guidelines](#development-guidelines).

5. **Test Your Changes**
   
   Test your changes thoroughly to ensure they work as expected and don't break existing functionality.

6. **Commit Changes**
   
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```
   
   Write clear, concise commit messages that describe your changes.

7. **Push to Your Fork**
   
   ```bash
   git push origin feature/your-feature-name
   ```

8. **Submit a Pull Request**
   
   Go to the original AZSC repository and click "New Pull Request". Select your fork and branch, then provide a detailed description of your changes.

9. **Address Review Feedback**
   
   Be responsive to any feedback provided by maintainers and make necessary changes.

## Development Guidelines

To maintain code quality and consistency:

- **Follow PowerShell Best Practices**: Follow [Microsoft's PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- **Document Your Code**: Add comments to explain complex logic and update documentation if needed
- **Keep It Modular**: Make sure your code follows the modular approach of AZSC
- **Error Handling**: Include appropriate error handling and logging
- **Backward Compatibility**: Ensure your changes don't break existing functionality
- **Test Thoroughly**: Test in various environments (Windows, Linux, Cloud Shell)

## Testing

AzureScout maintains **100% test coverage** across all 237 PowerShell scripts using [Pester 5](https://pester.dev). The full suite runs offline — no Azure credentials or live API calls are required.

### Prerequisites

```powershell
Install-Module Pester -MinimumVersion 5.3.2 -Force
Install-Module ImportExcel -Force
```

### Running Tests

```powershell
# Run the full suite (~1,240 tests)
Import-Module Pester -RequiredVersion 5.3.2 -Force
Invoke-Pester -Path .\tests\ -Output Detailed

# Run a single test file
Invoke-Pester -Path .\tests\Compute.Module.Tests.ps1 -Output Detailed
```

### Test Structure

The `tests/` directory contains **29 Pester test files** organized by area:

| Area | Files | What They Cover |
|------|:-----:|-----------------|
| Inventory Modules | 15 | One per Azure category (AI, Compute, Networking, etc.) — validates Processing and Reporting phases |
| Private Modules | 4 | Internal helpers: Main, Extraction, Processing, Reporting — file existence, syntax, function definitions |
| Public Functions | 1 | Diagram and Jobs utility scripts |
| Integration Tests | 9 | Module manifest, auth, Graph requests, permissions, output formats, category filtering |

### How Inventory Module Tests Work

Each inventory module test follows this pattern:

1. **Discovery** — A `$ResourceModules` array lists every module with its file path, Azure resource type, and worksheet name
2. **Mock Resources** — `BeforeAll` creates in-memory mock Azure resources (hashtables) matching each module's expectations
3. **Processing Phase** — The module script is loaded as a `ScriptBlock` and invoked with `Task = 'Processing'`. The test asserts non-null output
4. **Reporting Phase** — The same script is invoked with `Task = 'Reporting'` and the processed data. The test asserts the call completes without throwing

### Writing Tests for New Modules

When adding a new inventory module:

1. Identify the appropriate category test file (e.g., `Compute.Module.Tests.ps1`)
2. Add an entry to the `$ResourceModules` array with `Name`, `File`, `Type`, and `Worksheet`
3. Add a mock resource hashtable matching your module's expected resource type
4. Run the test file and verify both **Processing** (returns data) and **Reporting** (does not throw) phases pass

### Common Pitfalls

- **Case-sensitive hashtable keys** — Avoid duplicate keys like `SKU` and `sku` in mock data
- **ARM ID format** — Use full ARM paths (e.g., `/subscriptions/.../resourceGroups/.../providers/.../name`) — some modules call `.split('/')[8]`
- **DateTime values** — Modules casting to `[datetime]` require valid date strings in mocks
- **Cross-resource lookups** — Modules joining multiple resource types need mock resources for all related types
- **Export-Excel -PassThru** — Does not save to disk; test Reporting with `Should -Not -Throw` instead of file existence

### CI / CD Integration

```yaml
# GitHub Actions example
- name: Run Pester Tests
  shell: pwsh
  run: |
    Install-Module Pester -RequiredVersion 5.3.2 -Force -Scope CurrentUser
    Install-Module ImportExcel -Force -Scope CurrentUser
    Import-Module Pester -RequiredVersion 5.3.2 -Force
    $result = Invoke-Pester -Path ./tests/ -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) { exit 1 }
```

For the full testing guide, see `docs/modules/ROOT/pages/testing.adoc`.

## Project Structure

The main module **AzureScout.psm1** is only responsible for dot sourcing all the .ps1 modules.

### Public Modules

This modules will be loaded and the functions will be exposed to the user session


#### PublicFunctions

| Script File         | Description                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| `Invoke-AzureScout.ps1`    | Entry point script to invoke Azure Scout operations.          |


#### Diagram

| Script File                        | Description                                                                 |
|------------------------------------|-----------------------------------------------------------------------------|
| `Build-AZSCDiagramSubnet.ps1`       | Builds diagrams for Azure subnets.                                         |
| `Set-AZSCDiagramFile.ps1`           | Configures the file settings for diagram generation.                       |
| `Start-AZSCDiagramJob.ps1`          | Initiates the job for creating diagrams.                                   |
| `Start-AZSCDiagramNetwork.ps1`      | Starts the process for generating network diagrams.                        |
| `Start-AZSCDiagramOrganization.ps1` | Generates diagrams for organizational structures.                          |
| `Start-AZSCDiagramSubscription.ps1` | Creates diagrams for Azure subscriptions.                                  |
| `Start-AZSCDrawIODiagram.ps1`       | Generates diagrams compatible with Draw.io.                                |


#### Jobs

| Script File                     | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Start-AZSCAdvisoryJob.ps1`      | Initiates the advisory-related job for AZSC operations.                      |
| `Start-AZSCPolicyJob.ps1`        | Starts the job for processing Azure Policy-related tasks.                   |
| `Start-AZSCSecCenterJob.ps1`     | Initiates the job for handling Azure Security Center insights.              |
| `Start-AZSCSubscriptionJob.ps1`  | Starts the job for processing subscription-specific tasks.                  |
| `Wait-AZSCJob.ps1`               | Waits for the completion of AZSC jobs and monitors their status.             |


### Private Modules

This modules will be loaded and the functions will be available for the script and other functions to consume, but will not be exposed to the user session

#### 0.MainFunctions

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Clear-AZSCCacheFolder.ps1`           | Clears the AZSC cache folder to ensure a clean state for operations.         |
| `Clear-AZSCMemory.ps1`                | Frees up memory used by AZSC during operations.                              |
| `Connect-AZSCLoginSession.ps1`        | Establishes a login session with Azure for AZSC operations.                  |
| `Get-AZSCUnsupportedData.ps1`         | Retrieves data that is not currently supported by AZSC.                      |
| `Set-AZSCFolder.ps1`                  | Configures the folder structure for AZSC operations.                         |
| `Set-AZSCReportPath.ps1`              | Sets the path for storing AZSC-generated reports.                            |
| `Start-AZSCExtractionOrchestration.ps1` | Initiates the orchestration process for resource extraction.                |
| `Start-AZSCProcessOrchestration.ps1`  | Starts the orchestration of AZSC's processing tasks.                         |
| `Start-AZSCReporOrchestration.ps1`    | Begins the orchestration for generating AZSC reports.                        |
| `Test-AZSCPS.ps1`                     | Tests the PowerShell environment and prerequisites for AZSC operations.      |


#### 1.ExtractionFunctions

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Get-AZSCAPIResources.ps1`            | Extracts resources using Azure APIs.                                        |
| `Get-AZSCManagementGroups.ps1`        | Retrieves Azure Management Group data.                                      |
| `Get-AZSCSubscriptions.ps1`           | Retrieves subscription details from Azure.                                  |
| `Invoke-AZSCInventoryLoop.ps1`        | Executes the inventory loop for resource extraction.                        |
| `Start-AZSCGraphExtraction.ps1`       | Initiates the extraction of Azure Resource Graph data.                      |


#### 1.ExtractionFunctions/ResourceDetails

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Get-AZSCVMQuotas.ps1`                | Retrieves quota details for Azure Virtual Machines.                         |
| `Get-AZSCVMSkuDetails.ps1`            | Retrieves SKU details for Azure Virtual Machines.                           |


#### 2.ProcessingFunctions

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Build-AZSCCacheFiles.ps1`            | Builds cache files for AZSC operations.                                      |
| `Invoke-AZSCAdvisoryJob.ps1`          | Executes advisory-related processing jobs.                                  |
| `Invoke-AZSCDrawIOJob.ps1`            | Executes jobs for generating Draw.io diagrams.                              |
| `Invoke-AZSCPolicyJob.ps1`            | Executes policy-related processing jobs.                                    |
| `Invoke-AZSCSecurityCenterJob.ps1`    | Executes jobs related to Azure Security Center insights.                    |
| `Invoke-AZSCSubJob.ps1`               | Executes subscription-specific processing jobs.                             |
| `Start-AZSCAutProcessJob.ps1`         | Initiates automated processing jobs for AZSC.                                |
| `Start-AZSCExtraJobs.ps1`             | Starts additional processing jobs for extended functionality.               |
| `Start-AZSCProcessJob.ps1`            | Initiates the main processing jobs for AZSC operations.                      |


#### 3.ReportingFunctions

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Build-AZSCAdvisoryReport.ps1`        | Generates advisory reports based on processed data.                         |
| `Build-AZSCPolicyReport.ps1`          | Generates policy compliance reports.                                        |
| `Build-AZSCQuotaReport.ps1`           | Generates quota usage reports.                                              |
| `Build-AZSCSecCenterReport.ps1`       | Generates reports for Azure Security Center insights.                       |
| `Build-AZSCSubsReport.ps1`            | Generates subscription-specific reports.                                    |
| `Start-AZSCExcelJob.ps1`              | Initiates Excel-related reporting jobs.                                     |
| `Start-AZSCExtraReports.ps1`          | Starts additional reporting jobs for extended functionality.                |

#### 3.ReportingFunctions/StyleFunctions

| Script File                          | Description                                                                 |
|--------------------------------------|-----------------------------------------------------------------------------|
| `Build-AZSCExcelChart.ps1`            | Creates Excel charts for visualizing report data.                           |
| `Build-AZSCExcelComObject.ps1`        | Manages Excel COM objects for report generation.                            |
| `Build-AZSCExcelinitialBlock.ps1`     | Sets up the initial block for Excel report customization.                   |
| `Out-AZSCReportResults.ps1`           | Outputs the final report results to Excel or other formats.                 |
| `Retirement.kql`                     | Contains KQL queries for data retirement analysis.                          |
| `Start-AZSCExcelCustomization.ps1`    | Customizes Excel reports with specific formatting and styles.               |
| `Start-AZSCExcelOrdening.ps1`         | Orders and organizes data in Excel reports.                                 |
| `Support.json`                       | Provides configuration or metadata support for reporting functions.         |





Each module is designed to handle specific tasks, ensuring a clean and modular approach to AZSC's functionality.



### Resource Types

#### Resource Type Modules

The supported resource types by Azure Scout are defined by the "Resource Type Modules", we made sure to create this structure to be as simple as possible. 

So anyone could contribute by creating new modules for new resource types.

There is a Resource Type Module file for every single resource type supported by AZSC, the structure of resource type module itself is explained in the "Module-template.tpl", located in Modules/Public/InventoryModules.

Once you create the module file, it must be placed in the correct folder structure under Modules/Public/InventoryModules. The subfolder structure follows the official Azure documentation for Resource Providers: [azure-services-resource-providers](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers)


#### Resource Type Subfolders

| Category       | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| **AI**         | Scripts for processing AI services like Azure AI, Computer Vision, and more. |
| **Analytics**  | Scripts for processing analytics services like Databricks, Data Explorer, and Purview. |
| **APIs**       | Scripts for processing data captured through REST APIs.                    |
| **Compute**    | Scripts for processing compute resources such as VMs and VM Scale Sets.    |
| **Container**  | Scripts for processing container resources like AKS and Azure Container Instances. |
| **Database**   | Scripts for processing database services like SQL, MySQL, and Cosmos DB.   |
| **Hybrid**     | Scripts for processing hybrid cloud resources like Azure Arc.              |
| **Integration**| Scripts for processing service integration resources like Logic Apps and Service Bus. |
| **IoT**        | Scripts for processing IoT resources like IoT Hub and Azure Digital Twins. |
| **Management** | Scripts for processing management and governance resources like Azure Policy. |
| **Monitoring** | Scripts for processing monitoring services like Azure Monitor and Log Analytics. |
| **Network_1**  | Scripts for processing core networking resources like VNets and NSGs.      |
| **Network_2**  | Scripts for processing advanced networking resources like Azure Firewall and WAF. |
| **Security**   | Scripts for processing security services like Azure Security Center and Sentinel. |
| **Storage**    | Scripts for processing Azure Storage services like Blob, File, and Queue.  |
| **Web**        | Scripts for processing web services like App Services and Azure Functions. |




## Getting Help

If you have questions or need help with your contribution:

- **Open an Issue**: Create a new issue in the [GitHub repository](https://github.com/thisismydemo/azure-scout/issues)
- **Documentation**: Refer to the [README.md](README.md) and other documentation
- **Community Discussions**: Check existing discussions in the Issues tab

---

Thank you for contributing to Azure Scout! Your efforts help make cloud administration easier for the entire Azure community.

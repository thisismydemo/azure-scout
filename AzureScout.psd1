#
# Module manifest for module 'AzureScout'
#
# Author: Kristopher Turner
#
# Created: 2026-02-22
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AzureScout.psm1'

# Version number of this module.
ModuleVersion = '3.3.4'

# Supported PSEditions
CompatiblePSEditions = @('Core')

# ID used to uniquely identify this module
GUID = 'a0785538-fd96-4960-bf93-c733f88519e0'

# Author of this module
Author = 'Kristopher Turner'

# Company or vendor of this module
CompanyName = 'Hybrid Cloud Solutions'

# Copyright statement for this module
Copyright = '(c) 2026 Hybrid Cloud Solutions. All rights reserved.'

# Description of the functionality provided by this module
Description = 'AzureScout — discover, inventory, and assess everything in your Azure environment from one command. Run Invoke-AzureScout with no parameters for a guided wizard, or drive it with switches: by default it inventories Azure resources, Entra ID, and identity objects (Excel, JSON, Markdown, AsciiDoc); add -Assessment and it runs a read-only CAF/WAF landing-zone assessment, scoring the tenant against Cloud Adoption Framework design areas and Well-Architected pillars and producing Power BI, self-contained HTML, executive PowerPoint, and JSON/Excel evidence. See everything. Own your cloud. (Requires PowerShell 7 on PowerShell Core.)'

# Minimum version of the PowerShell engine required by this module
# AzureScout requires PowerShell 7+. Declaring this here makes Import-Module reject
# Windows PowerShell 5.1 (Desktop) cleanly and immediately, instead of the module
# loading and later crashing deep inside a strict-mode-sensitive code path (e.g. the
# Entra/Graph permission audit — see Invoke-AZTIPermissionAudit.ps1).
PowerShellVersion = '7.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
            #Public Jobs
            'Start-AZSCAdvisoryJob',
            'Start-AZSCPolicyJob',
            'Start-AZSCSecCenterJob',
            'Start-AZSCSubscriptionJob',
            'Wait-AZSCJob',

            #Public Diagram Functions
            'Build-AZSCDiagramSubnet',
            'Set-AZSCDiagramFile',
            'Start-AZSCDiagramJob',
            'Start-AZSCDiagramNetwork',
            'Start-AZSCDiagramOrganization',
            'Start-AZSCDiagramSubscription',
            'Start-AZSCDrawIODiagram',

            #Main Functions
            'Invoke-AzureScout',
            'Test-AZSCPermissions',

            #Guided setup wizard (AB#5541) -- what a bare Invoke-AzureScout opens
            'Start-AZSCWizard',

            #Assessment platform entry points (Epics AB#5023 / AB#5056, AB#5024)
            # Invoke-AzureScout is the supported assessment entry point.
            'Test-ScoutPermission',

            #Unattended pipeline entry point (AB#5050)
            'Invoke-ScoutPipeline',

            #Analysis functions -- offline, never call Azure (AB#324/AB#325/AB#326)
            'Get-ScoutInventoryDrift',
            'Get-ScoutCostAnomaly',
            'Get-ScoutIacGap',

            #Assessment config load/save (AB#373/AB#374)
            'Import-ScoutConfig',
            'Export-ScoutConfig'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Azure','AzureScout','Discovery','Inventory','Assessment','CAF','WAF','WellArchitected','CloudAdoptionFramework','LandingZone','Governance','AZSC','EntraID','Resources','ARM','Graph','Reporting','Excel','PowerBI')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/thisismydemo/azure-scout/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://thisismydemo.cloud/azure-scout/'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/thisismydemo/azure-scout/main/docs/images/azurescout-icon.svg'

        # ReleaseNotes of this module
        ReleaseNotes = 'v3.3.4 - One report, and it is the deliverable. Azure Scout produced six rendered report formats. A full multi-tenant render, read end to end rather than counted, found every one of them weak in a different way: a dashboard that drew its headers and no data, a maturity report scoring 10/10 with no explanation of what it measured, documents that never named which assessment they were, text drawn over text in the PDF, figures running off the slide, and a Word file that opened with a repair prompt. Six renderers maintained in parallel is WHY none of them reached deliverable quality. The React single-page report is now the product deliverable: one self-contained page hosting the inventory and every assessment behind an adaptive shell, whose navigation is built from what actually ran - an inventory-only run shows inventory, a full run shows inventory plus per-assessment detail. Each assessment answers three questions in order: what was run (scope, checks executed, and what was NOT assessed and why), what was found (findings with their evidence and real resource ids), and what to fix against CAF/WAF guidance. Every score is shown with its own arithmetic - numerator, denominator, and what was excluded as not-applicable - so a number can be checked rather than trusted; that is the direct answer to a maturity report claiming 10/10 while a landing-zone assessment of the same tenant scored 36%. Every other rendered format is ON HOLD: -OutputFormat All now renders the React report plus the machine-readable data exports. Json/JsonEvidence are deliberately NOT held - they are data, not documents, and the corpus harness and drift history read them. A held format asked for BY NAME warns, is skipped, and the React report renders anyway, so a run never returns an empty folder; the parameter still accepts every format name so existing scripts bind and get an explanation rather than a binding failure; and the default -OutputFormat moves from Html (itself now held) to React. The renderers are untouched and still tested - they are being rebuilt to generate FROM the React report rather than alongside it, so a document and the page it came from can no longer disagree, and lifting the hold is a one-line edit. Also: a cited Microsoft Learn guidance URL returned 404. The CAF Platform automation design area was cited as .../platform-automation-and-devops and stamped "verified 2026-08-01"; that URL 404s and the canonical page has no "and". Those citations are surfaced to the reader as the guidance for a finding, so the deliverable carried a dead link - and a verified-date stamp is no protection, because Microsoft renamed the page after the verification and nothing looked again. scripts/Test-ScoutGuidanceLinks.ps1 now HEADs every cited Learn URL across the rule files and reports each dead one with its file and line; it is a script rather than a Pester test on purpose, because it needs outbound network and a CI suite that fails when Microsoft has a bad afternoon is a suite people learn to ignore. 26 citations audited, this was the only rotted one. v3.3.3 - The corpus told the truth: five collection defects fixed, none visible from a green unit suite; every one was found by re-collecting eight real tenants into the banked corpus and refusing to explain away an empty dataset. The v3.3.2 Recovery Services vault fix never reached the collect result - the copy loop walks the typed-query keys and recoveryVaults has none, and the fallback guard tested a HASHTABLE''s PSObject adapter (which exposes Keys/Values/Count, never the keys), so the branch was unconditionally dead; vaults now copy explicitly and a structural gate test fails if any shaped dataset is left without a hand-off. Export-Pptx defined a module-scope Get-ScoutProp that shadowed the collect walker of the same name, so every PRODUCT run read nested properties.* as null (subnets, TLS versions, retention days) while every dot-sourced harness probe passed - the defect that corrupted the banked corpus and mis-diagnosed three healthy collectors; the renderer helper is renamed and a test bans same-name module-scope functions. Management groups are collected for the first time in the product''s history: the Resource Graph query never passed -UseTenantScope, so it returned zero rows everywhere - now 92 management groups across the eight reference tenants. security.defenderPlans was a hardcoded empty array from the day the contract was written, while the CAF and WAF security rules queried it for Standard-tier plans - they could never pass; plans are now collected per subscription over plain ARM REST with no Az.Security dependency, an unregistered Microsoft.Security provider stays quiet, and one live subscription banks 18 plans (4 Standard) where every prior run banked zero. Two assessment runs started within the same second no longer share one run folder - the second used to overwrite the first''s artefacts and replace its drift-history record. The corpus itself is now a committed harness: per-tenant integrity checks at collection time, per-collector coverage verdicts offline - 36 collect keys proven working across 8 real tenants, 23 empty-everywhere each with a maintained explanation, 0 unexplained. v3.3.2 - Field fixes found by running against real customer tenants rather than fixtures. Az.Advisor could abort the Advisor sweep for an ENTIRE tenant and surface as a raw stack trace mid-run ("Expected { or [. Was String: The.") - a defect in Az.Advisor 3.0.0 meeting a plain-text Azure error, almost always Microsoft.Advisor not registered on that subscription. Scout cannot prevent it but now contains it: the try/catch is per subscription, each failure is named and translated, and a closing summary gives the Register-AzResourceProvider command that fixes it. A licence boundary is no longer reported as a permission denial: IdentityRiskyUser.Read.All reported DENIED on tenants that had already consented, but Identity Protection is an Entra ID P2 feature and without P2 the endpoint returns nothing however much consent it has - so the advice could never work, and since most tenants lack P2 the common case was being reported as an error. Scout now reads subscribedSkus and reports NOT LICENSED, naming the product; the affected collectors are still reported as Not assessed so the gap stays visible, and the check is three-state so a failed SKU lookup never softens a genuine denial. Recovery Services vaults are collected: management.recoveryVaults was hardcoded to an empty array, so no run in the product history ever reported a vault while backupProtectedItems returned rows - a child with no parent. Costs no extra Resource Graph round-trip because the vault lives in the ordinary resources table the raw pass already reads. A landing-zone audit now scores the landing zone: LandingZone declared caf.*, waf.* which swept in every workload rule set (AI, AVD, Azure Local, IoT, AVS), scoring 34 areas where the audit covers 14; the eight CAF design areas and five WAF pillars are enumerated and a new workload file cannot join by filename alone. Also: GovernanceReport was missing from -OutputFormat All so the CAF Govern maturity score never rendered on a default run; evidence truncation is now visible (a finding with 198 matches said 25 and looked identical to one with 26, rows now read "25 of 198 matched"); and the docs carry licence tiers plus both field errors. Known limitation: networking.subnets returns no rows - diagnosed, not shipped half-verified. v3.3.1 - Completes the two clauses v3.3.0 shipped as known limitations. Figures now embed in PowerPoint and PDF, not only Word: the deck places one figure per slide as a real picture part, and the PDF embeds them as image XObjects because PDF FlateDecode is zlib -- exactly what the rasteriser already produces -- so the raw pixels go in with no decode round trip, no JPEG and no new dependency, which retires the manual diagram.jpg drop-in as the only route. And the Power BI report pages now bind to the model: a visual container needs three serialised blobs (config, query and dataTransforms) and only config was written, so nothing told Power BI which field belonged in which well and it drew the frames empty, with no error anywhere in that path - the project was structurally valid and the visuals were simply unbound, which is why every file-shape assertion passed while the report was useless. All eleven visuals across the three pages now carry their query and field-well mapping. Verified by re-rendering all eight tenants offline from banked collect data: 29 artefacts each, 0 empty. See CHANGELOG.md for the full history.'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}


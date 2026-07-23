#
# Azure Scout — assessment module registry
#
# Every assessment declares:
#   Description  human summary
#   Category     the Scout -Category it scopes discovery to ('*' = all)
#   Collect      collect categories to gather
#   Ingest       third-party collectors to fold into collect.json
#   Rules        rule-file glob patterns (caf.<domain> / waf.<domain>)
#   Frameworks   the CAF areas / WAF pillars this assessment maps to
#   Tags         classification tags
#   Benchmark    optional benchmark reference
#   Reporters    default output renderers
#
# Adding an assessment = adding an entry here plus a rule file. No core change.
# See docs/design/assessment-registry.md for the full catalogue (AB#5057).
#
@{
    # ---- cross-category roll-ups ----
    LandingZone = @{
        Description = 'CAF/WAF landing zone audit (all areas)'
        Category    = '*'
        # Rules = caf.*, waf.* pulls in every rule file (all 8 CAF areas + all 5 WAF
        # pillars, including the per-domain rule files from Epic AB#5056), so Collect
        # must gather every category too, not the 5-category subset this used to list
        # — now that -Categories actually filters which ARG queries Invoke-Collect
        # runs, an incomplete list here would silently starve Storage/Databases/Web/
        # Containers/Analytics/AI/Integration/Hybrid/IoT/Compute/Cost rules of data.
        Collect     = @('*')
        Ingest      = @('AzGovViz', 'ArgQueryPack', 'AdvisorScores')
        Rules       = @('caf.*', 'waf.*')
        Frameworks  = @('CAF: all 8 design areas', 'WAF: all 5 pillars')
        Tags        = @('caf', 'waf', 'landing-zone')
        Benchmark   = 'alz-reference.json'
        Reporters   = @('PowerBi', 'Html', 'Pptx')
    }
    Estate = @{
        Description = 'Full digital estate inventory (no scoring)'
        Category    = '*'
        Collect     = @('*')
        Ingest      = @()
        Rules       = @()
        Frameworks  = @()
        Tags        = @('inventory')
        Reporters   = @('Excel', 'PowerBi')
    }

    # ---- per-category assessments (Epic AB#5056) ----
    Management = @{
        Description = 'Governance, policy, cost, backup, automation, update manager'
        Category    = 'Management'; Collect = @('Management'); Ingest = @('AzGovViz', 'ArgQueryPack', 'AdvisorScores')
        Rules = @('caf.governance', 'caf.management', 'caf.billing'); Frameworks = @('CAF: Governance', 'CAF: Management', 'CAF: Billing', 'WAF: Operational', 'WAF: Cost')
        Tags = @('caf', 'governance', 'management'); Reporters = @('Html', 'Excel')
    }
    Monitor = @{
        Description = 'Monitoring, alerting, diagnostics coverage'
        Category    = 'Monitor'; Collect = @('Monitor'); Ingest = @('ArgQueryPack')
        Rules = @('caf.management', 'waf.operational'); Frameworks = @('CAF: Management & monitoring', 'WAF: Operational excellence')
        Tags = @('waf', 'monitor'); Reporters = @('Html', 'Excel')
    }
    Networking = @{
        Description = 'Network topology, firewall, DDoS, exposure, private link'
        Category    = 'Networking'; Collect = @('Networking'); Ingest = @('ArgQueryPack')
        Rules = @('caf.network'); Frameworks = @('CAF: Network topology & connectivity', 'WAF: Security')
        Tags = @('caf', 'networking'); Reporters = @('Html', 'Excel')
    }
    Identity = @{
        Description = 'Identity & access — PIM, Conditional Access, RBAC'
        Category    = 'Identity'; Collect = @('Identity', 'Security'); Ingest = @('AzGovViz')
        Rules = @('caf.identity'); Frameworks = @('CAF: Identity & access management', 'WAF: Security')
        Tags = @('caf', 'identity'); Reporters = @('Html', 'Excel')
    }
    Security = @{
        Description = 'Defender, Key Vault, secure score, exposure'
        Category    = 'Security'; Collect = @('Security'); Ingest = @('AdvisorScores', 'ArgQueryPack')
        Rules = @('caf.security', 'waf.security'); Frameworks = @('CAF: Security', 'WAF: Security')
        Tags = @('caf', 'waf', 'security'); Reporters = @('Html', 'Excel')
    }
    Compute = @{
        Description = 'VM resilience, zones, backup, right-size, orphans'
        Category    = 'Compute'; Collect = @('Compute'); Ingest = @('ArgQueryPack', 'AdvisorScores')
        Rules = @('waf.reliability', 'waf.cost', 'waf.performance'); Frameworks = @('WAF: Reliability', 'WAF: Cost', 'WAF: Performance efficiency')
        Tags = @('waf', 'compute'); Reporters = @('Html', 'Excel')
    }
    Storage = @{
        Description = 'Storage public access, TLS, encryption, redundancy'
        Category    = 'Storage'; Collect = @('Storage'); Ingest = @('ArgQueryPack')
        Rules = @('caf.storage', 'waf.storage'); Frameworks = @('CAF: Security', 'WAF: Reliability')
        Tags = @('caf', 'waf', 'storage'); Reporters = @('Html', 'Excel')
    }
    Databases = @{
        Description = 'SQL/DB private access, TDE, zone redundancy'
        Category    = 'Databases'; Collect = @('Databases'); Ingest = @('ArgQueryPack')
        Rules = @('caf.databases'); Frameworks = @('CAF: Security', 'WAF: Reliability')
        Tags = @('caf', 'databases'); Reporters = @('Html', 'Excel')
    }
    Containers = @{
        Description = 'AKS private clusters, RBAC, registry hardening'
        Category    = 'Containers'; Collect = @('Containers'); Ingest = @('ArgQueryPack')
        Rules = @('caf.containers'); Frameworks = @('CAF: Security', 'WAF: Reliability')
        Tags = @('caf', 'containers'); Reporters = @('Html', 'Excel')
    }
    Web = @{
        Description = 'App Service HTTPS-only, TLS, managed identity'
        Category    = 'Web'; Collect = @('Web'); Ingest = @('ArgQueryPack')
        Rules = @('caf.web'); Frameworks = @('CAF: Security', 'WAF: Security')
        Tags = @('caf', 'web'); Reporters = @('Html', 'Excel')
    }
    Analytics = @{
        Description = 'Analytics data governance and network isolation'
        Category    = 'Analytics'; Collect = @('Analytics'); Ingest = @('ArgQueryPack')
        Rules = @('caf.analytics'); Frameworks = @('CAF: Governance', 'WAF: Security')
        Tags = @('caf', 'analytics'); Reporters = @('Html', 'Excel')
    }
    AI = @{
        Description = 'AI/Cognitive private access and responsible-AI posture'
        Category    = 'AI'; Collect = @('AI'); Ingest = @('ArgQueryPack')
        Rules = @('caf.ai'); Frameworks = @('CAF: Governance', 'WAF: Security')
        Tags = @('caf', 'ai'); Reporters = @('Html', 'Excel')
    }
    Integration = @{
        Description = 'Messaging redundancy and APIM network isolation'
        Category    = 'Integration'; Collect = @('Integration'); Ingest = @('ArgQueryPack')
        Rules = @('caf.integration'); Frameworks = @('CAF: Network topology & connectivity', 'WAF: Reliability')
        Tags = @('caf', 'integration'); Reporters = @('Html', 'Excel')
    }
    Hybrid = @{
        Description = 'Arc onboarding, agent currency, Azure Local'
        Category    = 'Hybrid'; Collect = @('Hybrid'); Ingest = @('ArgQueryPack')
        Rules = @('caf.hybrid'); Frameworks = @('CAF: Management & monitoring', 'WAF: Operational excellence')
        Tags = @('caf', 'hybrid'); Reporters = @('Html', 'Excel')
    }
    IoT = @{
        Description = 'IoT Hub/DPS network isolation and device auth'
        Category    = 'IoT'; Collect = @('IoT'); Ingest = @('ArgQueryPack')
        Rules = @('caf.iot'); Frameworks = @('CAF: Security', 'WAF: Security')
        Tags = @('caf', 'iot'); Reporters = @('Html', 'Excel')
    }

    # ---- finer sub-bundles inside a category ----
    Governance = @{
        Description = 'Management sub-bundle — policy assignments, locks, budgets'
        Category    = 'Management'; Collect = @('Management'); Ingest = @('AzGovViz')
        Rules = @('caf.governance'); Frameworks = @('CAF: Governance'); Tags = @('caf', 'governance', 'sub-bundle'); Reporters = @('Html')
    }
    Policy = @{
        Description = 'Management sub-bundle — Azure Policy assignment/enforcement'
        Category    = 'Management'; Collect = @('Management'); Ingest = @('AzGovViz')
        Rules = @('caf.governance'); Frameworks = @('CAF: Governance'); Tags = @('caf', 'policy', 'sub-bundle'); Reporters = @('Html')
    }
    UpdateManager = @{
        Description = 'Management sub-bundle — patch/update compliance'
        Category    = 'Management'; Collect = @('Management'); Ingest = @('ArgQueryPack')
        Rules = @('caf.management'); Frameworks = @('WAF: Operational excellence'); Tags = @('waf', 'update-manager', 'sub-bundle'); Reporters = @('Html')
    }
    Monitoring = @{
        Description = 'Monitor sub-bundle — diagnostic settings coverage'
        Category    = 'Monitor'; Collect = @('Monitor'); Ingest = @('ArgQueryPack')
        Rules = @('waf.operational'); Frameworks = @('WAF: Operational excellence'); Tags = @('waf', 'monitoring', 'sub-bundle'); Reporters = @('Html')
    }

    # ---- targeted cost pull ----
    Cost = @{
        Description = 'Cost / TCO data pull'
        Category    = '*'; Collect = @('Cost', 'Compute', 'Storage'); Ingest = @('AdvisorScores', 'ArgQueryPack')
        Rules = @('waf.cost'); Frameworks = @('WAF: Cost optimization'); Tags = @('waf', 'cost'); Reporters = @('Excel', 'PowerBi')
    }
}

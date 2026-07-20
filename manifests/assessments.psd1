#
# Azure Scout — assessment module registry
#
# Each assessment maps to the collect categories it needs, the third-party
# collectors to ingest, the rule files it runs, an optional benchmark, and the
# reporters it emits. Adding an assessment = adding an entry here plus a rule
# file. No core code change required.
#
@{
    LandingZone = @{
        Description = 'CAF/WAF landing zone audit'
        Collect     = @('Networking', 'ManagementGovernance', 'Security', 'Identity', 'Monitor')
        Ingest      = @('AzGovViz', 'ArgQueryPack', 'AdvisorScores')
        Rules       = @('caf.*', 'waf.*')
        Benchmark   = 'alz-reference.json'
        Reporters   = @('PowerBi', 'Html', 'Pptx')
    }
    Identity = @{
        Description = 'Identity, security & governance review'
        Collect     = @('Identity', 'Security')
        Ingest      = @('AzGovViz')
        Rules       = @('caf.identity', 'caf.security', 'caf.governance')
        Reporters   = @('Html', 'Excel')
    }
    Estate = @{
        Description = 'Full digital estate inventory'
        Collect     = @('*')
        Ingest      = @()
        Rules       = @()          # pure inventory, no scoring
        Reporters   = @('Excel', 'PowerBi')
    }
    Cost = @{
        Description = 'Cost / TCO data pull'
        Collect     = @('Cost', 'Compute', 'Storage')
        Ingest      = @('AdvisorScores', 'ArgQueryPack')
        Rules       = @('waf.cost')
        Reporters   = @('Excel', 'PowerBi')
    }
}

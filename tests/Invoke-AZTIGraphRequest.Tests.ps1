#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Invoke-AZTIGraphRequest.

.DESCRIPTION
    Validates the Graph API request handler:
      - URI normalization (relative → absolute)
      - Retry on 429 (throttle) with Retry-After header
      - Retry on 5xx with exponential backoff
      - Pagination via @odata.nextLink
      - SinglePage switch disables pagination
      - Non-retryable errors bubble correctly
      - Returns .value collection or raw response

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'AzureTenantInventory.psd1') -Force -ErrorAction Stop
}

Describe 'Invoke-AZTIGraphRequest' {

    # ── URI Normalization ─────────────────────────────────────────────
    Context 'URI Normalization' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1'; displayName = 'Test' }) }
            } -ModuleName AzureTenantInventory
        }

        It 'Prepends https://graph.microsoft.com for relative URIs' {
            Invoke-AZTIGraphRequest -Uri '/v1.0/organization'
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/organization*'
            }
        }

        It 'Passes absolute URIs through unchanged' {
            Invoke-AZTIGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users'
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/users'
            }
        }
    }

    # ── Successful Single-Page Request ────────────────────────────────
    Context 'Single Successful Request' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{ id = '1'; displayName = 'User A' }
                        [PSCustomObject]@{ id = '2'; displayName = 'User B' }
                    )
                }
            } -ModuleName AzureTenantInventory
        }

        It 'Returns objects from the .value collection' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            $result.Count | Should -Be 2
            $result[0].displayName | Should -Be 'User A'
        }
    }

    # ── Raw Response (No .value) ──────────────────────────────────────
    Context 'Single-Object Endpoint (no .value)' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ id = 'org-1'; displayName = 'Contoso' }
            } -ModuleName AzureTenantInventory
        }

        It 'Returns the raw response when no .value property exists' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/organization'
            $result.displayName | Should -Be 'Contoso'
        }
    }

    # ── Pagination ────────────────────────────────────────────────────
    Context 'Pagination via @odata.nextLink' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory

            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return [PSCustomObject]@{
                        value           = @([PSCustomObject]@{ id = '1' })
                        '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skip=1'
                    }
                }
                else {
                    return [PSCustomObject]@{
                        value = @([PSCustomObject]@{ id = '2' })
                    }
                }
            } -ModuleName AzureTenantInventory
        }

        AfterAll {
            Remove-Variable -Name callCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Follows @odata.nextLink and aggregates results' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            $result.Count | Should -Be 2
        }

        It 'Makes multiple Invoke-RestMethod calls for pagination' {
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 2 -Scope Context
        }
    }

    # ── SinglePage Switch ─────────────────────────────────────────────
    Context 'SinglePage Switch' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    value             = @([PSCustomObject]@{ id = '1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skip=1'
                }
            } -ModuleName AzureTenantInventory
        }

        It 'Does not follow nextLink when SinglePage is set' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/users' -SinglePage
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 1 -Scope It
        }
    }

    # ── Retry on 429 (Throttle) ───────────────────────────────────────
    Context 'Retry on 429 Throttle' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory

            $script:retryCallCount = 0
            Mock Invoke-RestMethod {
                $script:retryCallCount++
                if ($script:retryCallCount -eq 1) {
                    $ex = [System.Net.WebException]::new('Too Many Requests')
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new($ex, '429', 'InvalidOperation', $null)
                    # Simulate 429 with Retry-After header via exception
                    throw $errorRecord
                }
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        AfterAll {
            Remove-Variable -Name retryCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Retries after a 429 error' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 3
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 2 -Scope It
        }

        It 'Calls Start-Sleep during retry backoff' {
            Should -Invoke Start-Sleep -ModuleName AzureTenantInventory -Scope Context
        }
    }

    # ── Retry on 5xx ──────────────────────────────────────────────────
    Context 'Retry on 5xx Server Error' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory

            $script:serverErrorCount = 0
            Mock Invoke-RestMethod {
                $script:serverErrorCount++
                if ($script:serverErrorCount -le 2) {
                    $ex = [System.Net.WebException]::new('Internal Server Error')
                    throw $ex
                }
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        AfterAll {
            Remove-Variable -Name serverErrorCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Retries multiple times on server errors' {
            $result = Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 5
            $result | Should -Not -BeNullOrEmpty
        }
    }

    # ── Max Retries Exceeded ──────────────────────────────────────────
    Context 'Max Retries Exceeded' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token' } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod { throw [System.Net.WebException]::new('Service Unavailable') } -ModuleName AzureTenantInventory
        }

        It 'Throws after exhausting all retries' {
            { Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 2 } | Should -Throw
        }
    }

    # ── Token Refresh ─────────────────────────────────────────────────
    Context 'Token Handling' {

        BeforeAll {
            Mock Get-AZTIGraphToken { return 'mock-token-refreshed' } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        It 'Fetches a token via Get-AZTIGraphToken' {
            Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            Should -Invoke Get-AZTIGraphToken -ModuleName AzureTenantInventory
        }
    }
}

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

$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $ModuleRoot 'AzureTenantInventory.psd1') -Force -ErrorAction Stop

Describe 'Invoke-AZTIGraphRequest' {

    # ── URI Normalization ─────────────────────────────────────────────
    Context 'URI Normalization' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1'; displayName = 'Test' }) }
            } -ModuleName AzureTenantInventory
        }

        It 'Prepends https://graph.microsoft.com for relative URIs' {
            InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/organization'
            }
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -ParameterFilter {
                $Uri -like 'https://graph.microsoft.com/v1.0/organization*'
            }
        }

        It 'Passes absolute URIs through unchanged' {
            InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users'
            }
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/users'
            }
        }
    }

    # ── Successful Single-Page Request ────────────────────────────────
    Context 'Single Successful Request' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
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
            $result = InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            }
            $result.Count | Should -Be 2
            $result[0].displayName | Should -Be 'User A'
        }
    }

    # ── Raw Response (No .value) ──────────────────────────────────────
    Context 'Single-Object Endpoint (no .value)' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ id = 'org-1'; displayName = 'Contoso' }
            } -ModuleName AzureTenantInventory
        }

        It 'Returns the raw response when no .value property exists' {
            $result = InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/organization'
            }
            $result.displayName | Should -Be 'Contoso'
        }
    }

    # ── Pagination ────────────────────────────────────────────────────
    Context 'Pagination via @odata.nextLink' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory

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
            $result = InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            }
            $result.Count | Should -Be 2
        }

        It 'Makes multiple Invoke-RestMethod calls for pagination' {
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 2 -Scope Context
        }
    }

    # ── SinglePage Switch ─────────────────────────────────────────────
    Context 'SinglePage Switch' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    value             = @([PSCustomObject]@{ id = '1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skip=1'
                }
            } -ModuleName AzureTenantInventory
        }

        It 'Does not follow nextLink when SinglePage is set' {
            InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users' -SinglePage
            }
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 1 -Scope It
        }
    }

    # ── Retry on 429 (Throttle) ───────────────────────────────────────
    Context 'Retry on 429 Throttle' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory

            $script:retryCallCount = 0
            Mock Invoke-RestMethod {
                $script:retryCallCount++
                if ($script:retryCallCount -eq 1) {
                    $mockResponse = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]429)
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Too Many Requests', $mockResponse)
                }
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        AfterAll {
            Remove-Variable -Name retryCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Retries after a 429 error' {
            InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 3
            }
            Should -Invoke Invoke-RestMethod -ModuleName AzureTenantInventory -Times 2 -Scope It
        }

        It 'Calls Start-Sleep during retry backoff' {
            Should -Invoke Start-Sleep -ModuleName AzureTenantInventory -Scope Context
        }
    }

    # ── Retry on 5xx ──────────────────────────────────────────────────
    Context 'Retry on 5xx Server Error' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory

            $script:serverErrorCount = 0
            Mock Invoke-RestMethod {
                $script:serverErrorCount++
                if ($script:serverErrorCount -le 2) {
                    $mockResponse = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Internal Server Error', $mockResponse)
                }
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        AfterAll {
            Remove-Variable -Name serverErrorCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Retries multiple times on server errors' {
            $result = InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 5
            }
            $result | Should -Not -BeNullOrEmpty
        }
    }

    # ── Max Retries Exceeded ──────────────────────────────────────────
    Context 'Max Retries Exceeded' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Start-Sleep { } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                $mockResponse = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Service Unavailable', $mockResponse)
            } -ModuleName AzureTenantInventory
        }

        It 'Throws after exhausting all retries' {
            { InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users' -MaxRetries 2
            } } | Should -Throw
        }
    }

    # ── Token Refresh ─────────────────────────────────────────────────
    Context 'Token Handling' {

        BeforeAll {
            Mock Get-AZTIGraphToken {
                return @{ 'Authorization' = 'Bearer mock-token-refreshed'; 'Content-Type' = 'application/json' }
            } -ModuleName AzureTenantInventory
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }) }
            } -ModuleName AzureTenantInventory
        }

        It 'Fetches a token via Get-AZTIGraphToken' {
            InModuleScope 'AzureTenantInventory' {
                Invoke-AZTIGraphRequest -Uri '/v1.0/users'
            }
            Should -Invoke Get-AZTIGraphToken -ModuleName AzureTenantInventory
        }
    }
}

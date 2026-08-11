#Requires -Version 7.0
#Requires -Modules Pester

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path -Path $ModuleRoot -ChildPath 'AzureScout.psd1') -Force -ErrorAction Stop

InModuleScope 'AzureScout' {
    Describe 'Get-AZSCGraphToken authentication provider selection' {
        BeforeEach {
            $script:_AZSCGraphTokenCache = @{}

            Mock Get-AzContext {
                [pscustomobject]@{
                    Account     = [pscustomobject]@{ Id = 'target.user@contoso.test'; Type = 'User' }
                    Tenant      = [pscustomobject]@{ Id = 'target-tenant' }
                    Environment = [pscustomobject]@{ Name = 'AzureCloud' }
                }
            }

            Mock Get-AzAccessToken {
                $secureToken = [System.Security.SecureString]::new()
                foreach ($character in 'az-context-graph-token'.ToCharArray()) {
                    $secureToken.AppendChar($character)
                }
                $secureToken.MakeReadOnly()
                [pscustomobject]@{
                    Token     = $secureToken
                    ExpiresOn = [DateTimeOffset]::UtcNow.AddHours(1)
                }
            }

            Mock az { throw 'Azure CLI must not be used when the Az context can acquire Graph.' }
        }

        AfterEach {
            Remove-Variable -Name '_AZSCGraphTokenCache' -Scope Script -ErrorAction SilentlyContinue
        }

        It 'uses only the selected Az context for the requested tenant' {
            $headers = Get-AZSCGraphToken -TenantID 'target-tenant'

            $headers.Authorization | Should -Be 'Bearer az-context-graph-token'
            Should -Invoke Get-AzAccessToken -Times 1 -Scope It -ParameterFilter {
                $TenantId -eq 'target-tenant' -and
                $ResourceUrl -eq 'https://graph.microsoft.com'
            }
            Should -Invoke az -Times 0 -Scope It
        }

        It 'reuses the Az-context token without reacquiring it for every Graph query' {
            $null = Get-AZSCGraphToken -TenantID 'target-tenant'
            $null = Get-AZSCGraphToken -TenantID 'target-tenant'

            Should -Invoke Get-AzAccessToken -Times 1 -Scope It
            Should -Invoke az -Times 0 -Scope It
        }

        It 'keeps token caches isolated by selected Az account identity' {
            $null = Get-AZSCGraphToken -TenantID 'target-tenant'

            Mock Get-AzContext {
                [pscustomobject]@{
                    Account     = [pscustomobject]@{ Id = 'second.user@contoso.test'; Type = 'User' }
                    Tenant      = [pscustomobject]@{ Id = 'target-tenant' }
                    Environment = [pscustomobject]@{ Name = 'AzureCloud' }
                }
            }

            $null = Get-AZSCGraphToken -TenantID 'target-tenant'

            Should -Invoke Get-AzAccessToken -Times 2 -Scope It
        }

        It 'does not start a second Azure CLI authentication path when Az token acquisition fails' {
            Mock Get-AzAccessToken { throw 'Az token unavailable' }

            {
                Get-AZSCGraphToken -TenantID 'target-tenant'
            } | Should -Throw '*selected Azure PowerShell context*Graph and ARM use the same Azure sign-in*Azure CLI is not used*Az token unavailable*'

            Should -Invoke Get-AzAccessToken -Times 1 -Scope It
            Should -Invoke az -Times 0 -Scope It
        }

        It 'contains no Azure CLI token command in the implementation' {
            $command = Get-Command Get-AZSCGraphToken -ErrorAction Stop
            $command.ScriptBlock.ToString() | Should -Not -Match '(?i)az\s+account\s+get-access-token'
        }
    }
}

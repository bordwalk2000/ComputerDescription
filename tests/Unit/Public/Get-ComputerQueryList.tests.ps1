Describe "Get-ComputerQueryList Tests" {
    BeforeAll {
        . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')

        Mock Get-ADComputer -ParameterFilter { $Identity } -MockWith {
            $Object = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                Enabled           = 'True'
                Description       = 'Sales Computer'
                DistinguishedName = 'CN=Computer01,OU=Computers,DC=example,DC=com'
            }
            $Object['Name'].Add('Computer01') | Out-Null
            Write-Output $Object

            $Object = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                Enabled           = 'True'
                Description       = 'Manufacturing Computer'
                DistinguishedName = 'CN=Computer02,OU=Computers,DC=example,DC=com'
            }
            $Object['Name'].Add('Computer02') | Out-Null
            Write-Output $Object

            # $ADGroup = New-Object Microsoft.ActiveDirectory.Management.ADGroup Identity -Property @{
            # $ADGroup['Name'].Add('My group') | Out-Null
            # https://github.com/pester/Pester/issues/914
        }

        Mock Get-ADUser -ParameterFilter { $Identity } -MockWith {
            New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                Enabled           = 'True'
                Description       = 'Sales Computer'
                DistinguishedName = 'CN=Computer01,OU=Computers,DC=example,DC=com'
            }
        }

        Mock Get-ADgroup -ParameterFilter { $Identity } -MockWith {
            $Object =
            New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                Enabled           = 'True'
                Description       = 'Manufacturing Computer'
                DistinguishedName = 'CN=Computer02,OU=Computers,DC=example,DC=com'
            }
            $Object['Name'].Add('Computer02') | Out-Null
            Write-Output $Object
        }

        Mock Get-ADComputer -ParameterFilter { $SearchBase } -MockWith {
            $Object =
            New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Filter -Property @{
                Enabled           = 'True'
                Description       = 'IT Computer'
                DistinguishedName = 'CN=Computer101,OU=Computers,DC=example,DC=com'
            }
            $Object['Name'].Add('Computer101') | Out-Null
            Write-Output $Object

            $Object =
            New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Filter -Property @{
                Enabled           = 'True'
                Description       = 'Accounting Computer'
                DistinguishedName = 'CN=Computer102,OU=Computers,DC=example,DC=com'
            }
            $Object['Name'].Add('Computer102') | Out-Null
            Write-Output $Object
        }

        Mock Get-ADOrganizationalUnit {
            [PSCustomObject]@{ Name = "OU=Computers,DC=example,DC=com" }
        }
    }

    Context "When querying computers by OU path" {
        It "Should return computers within specified OU path" {
            $ouPath = "OU=Computers,DC=example,DC=com"
            $computers = Get-ComputerQueryList -OUPath $ouPath
            ($computers | Get-Member)[0].TypeName | Should -Be 'Selected.Microsoft.ActiveDirectory.Management.ADComputer'
            [bool]($computers.Name | Where-Object { @("Computer101", "Computer102") -notcontains $_ }) | Should -Be $false
        }
    }

    Context "When querying computers by name" {
        It "Should return details for existing computers" {
            $computerNames = @("Computer1", "Computer2")
            $computers = Get-ComputerQueryList -ComputerName $computerNames
            ($computers | Get-Member)[0].TypeName | Should -Be 'Selected.Microsoft.ActiveDirectory.Management.ADComputer'
            [bool]($computers.Name | Where-Object { @("Computer01", "Computer02") -notcontains $_ }) | Should -Be $false
        }
    }

    Context "When querying computers by both OU path and name" {
        It "Should return combined list of computers" {
            $ouPath = "OU=Computers,DC=example,DC=com"
            $computerNames = @("Computer01", "Computer02")
            $computers = Get-ComputerQueryList -OUPath $ouPath -ComputerName $computerNames
            ($computers | Get-Member)[0].TypeName | Should -Be 'Selected.Microsoft.ActiveDirectory.Management.ADComputer'
            [bool]($computers.Name | Where-Object { @("Computer01", "Computer02", "Computer101", "Computer102") -notcontains $_ }) | Should -Be $false
        }
    }
}
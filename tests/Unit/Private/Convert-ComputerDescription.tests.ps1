BeforeAll {
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')
}

Describe "Convert-ComputerDescription" {
    Context "When passing a single computer object with description" {
        It "Should extract and parse the computer description correctly" {
            # Create a mock Get-ADComputer
            Mock Get-ADComputer {
                param( $Identity )

                $Name = "John Doe"
                $ServiceTag = "ABC1235"
                $AssetTag = "AssetTagC001"
                $InstallDate = "Deployed 2022-01-01"
                $Object = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                    Description = "$Name | $ServiceTag | $AssetTag | $InstallDate"
                }
                $Object['Name'].Add( "$Identity" ) | Out-Null
                Write-Output $Object
            }

            # Create ADComputer Object
            $computerName = "TestComputer"
            $ADComputer = Get-ADComputer -Identity $computerName

            # Invoke the function with the mock object
            $Result = $ADComputer | Convert-ComputerDescription

            # Assert the properties of the output object
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'
            $Result.Source | Should -Be 'Parsed'
            $Result.Name | Should -Be 'TestComputer'
            $Result.PrimaryUser | Should -Be 'John Doe'
            $Result.ServiceTag | Should -Be 'ABC1235'
            $Result.ServiceTag.Length | Should -Be '7'
            # $Result.AssetTag | Should -Be 'AssetTagC001'
            [Boolean][DateTime]::Parse($Result.InstallDate.Split(' ')[-1]) | Should -BeTrue
        }
    }

    Context "When passing a single computer object without description" {
        It "Should return an object with empty properties except for Name and Description" {
            # Create a mock Get-ADComputer
            Mock Get-ADComputer {
                param( $Identity )
                $Object = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -ArgumentList Identity -Property @{
                    Description = ''
                }
                $Object['Name'].Add( "$Identity" ) | Out-Null
                Write-Output $Object
            }

            # Create ADComputer Object
            $computerName = "TestComputer2"
            $ADComputer = Get-ADComputer -Identity $computerName

            # Invoke the function with the mock object
            $Result = Convert-ComputerDescription -ComputerObject $ADComputer

            # Assert the properties of the output object
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'
            $Result.Source | Should -Be 'Parsed'
            $Result.Name | Should -Be 'TestComputer2'
            $Result.PrimaryUser | Should -BeNullOrEmpty
            $Result.ServiceTag | Should -BeNullOrEmpty
            $Result.AssetTag | Should -BeNullOrEmpty
            $Result.InstallDate | Should -BeNullOrEmpty
        }
    }

    Context "When passing a non-ADComputer object" {
        It "Should throw an error" {
            # Create a non-ADComputer object
            $NonADComputerObject = "TestString"

            # Assert that invoking the function with a non-ADComputer object throws an error
            { $NonADComputerObject | Convert-ComputerDescription } | Should -Throw
        }
    }
}
BeforeAll {
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')
}

Describe "Get-PrimaryUser" {
    Context "When providing a valid computer name" {
        It "Should return the primary user of the computer" {
            # Mocking Get-WinEvent cmdlet
            Mock Get-WinEvent {
                return @(
                    [PSCustomObject]@{
                        Properties = @(
                            [PSCustomObject]@{ Value = "User1" }
                        )
                    }
                )
            }

            # Call the function with a valid computer name
            $validComputerName = 'Computer01'
            $primaryUser = Get-PrimaryUser -ComputerName $validComputerName

            # Assert that the primary user is returned correctly
            $primaryUser | Should -BeExactly "User1"
        }
    }

    Context "When providing an invalid computer name" {
        It "Should throw an error" {
            # Mocking Get-WinEvent cmdlet to simulate an error
            Mock Get-WinEvent {
                throw "Computer not found"
            }

            # Call the function with an invalid computer name
            $invalidComputerName = 'InvalidComputer'
            { Get-PrimaryUser -ComputerName $invalidComputerName } | Should -Throw
        }
    }
}
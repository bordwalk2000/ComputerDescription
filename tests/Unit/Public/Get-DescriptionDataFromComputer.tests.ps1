# Have to disable because Mocking doesn't work with Dynamic Code.
# https://github.com/pester/Pester/issues/2115

BeforeAll {
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('Get-DescriptionDataFromComputer.tests.ps1', 'Get-PrimaryUser.ps1')

    Mock Get-PrimaryUser { return "Domain\User" }
}

Describe "Test Get-DescriptionDataFromComputer" {
    # Context "When computer is online and data can be pulled" {
    #     It "Should return object with correct data" {
    #         Mock Test-Connection { return $true }
    #         Mock Get-CimInstance { return @{ SerialNumber = "123456"; SMBiosAssetTag = "Asset123" } }
    #         Mock Get-ADUser { return @{ Name = "John Doe" } }
    #         Mock Get-CimInstance -ParameterFilter {
    #             $ClassName -eq 'Win32_OperatingSystem'
    #         } -MockWith {
    #             return @{ InstallDate = [datetime]"Saturday, January 1, 2022 5:00:00 PM" }
    #         }

    #         $computerName = "Computer1"
    #         $result = Get-DescriptionDataFromComputer -ComputerName $computerName
    #         $result | Should -BeOfType [PSCustomObject]
    #         $result.PSTypeNames | Should -Contain "ComputerDescription"
    #         $result.Name | Should -MatchExactly "COMPUTER1"
    #         $result.PrimaryUser | Should -Be "John Doe"
    #         $result.ServiceTag | Should -Be "123456"
    #         $result.AssetTag | Should -Be "ASSET123"
    #         $result.InstallDate | Should -Be "Deployed 2022-01-01"
    #     }
    # }

    # Context "When computer is offline" {
    #     It "Should return an error" {
    #         Mock Test-Connection { return $false }
    #         $computerName = "Computer2"
    #         { Get-DescriptionDataFromComputer -ComputerName $computerName } | Should -Throw
    #     }
    # }

    # Context "When unable to pull data" {
    #     It "Should return an error" {
    #         Mock Test-Connection { return $true }
    #         Mock Get-PrimaryUser { throw "Unable to access Get-PrimaryUser" }
    #         Mock Get-CimInstance { throw "Unable to access CIM instance" }
    #         $computerName = "Computer3"
    #         { Get-DescriptionDataFromComputer s-ComputerName $computerName } | Should -Throw
    #     }
    # }
}
BeforeAll {
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')
    . $PSScriptRoot.Replace('tests\Unit', 'source').Replace('Public', 'Private\New-ComputerDescriptionObject.ps1')
}

Describe "Get-ParsedDescriptionData" {
    Context "With valid input" {
        It "Returns parsed description data" {
            # Define test input
            $computerObject = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -Property @{
                Description = "John Doe | ABC1234 | Deployed 2023-05-10"
            }
            $computerObject['Name'].Add('Computer1') | Out-Null

            # Call the function
            $result = Get-ParsedDescriptionData -ComputerObject $computerObject

            # Assert the result is correct
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain "ComputerDescription"
            $result.Name | Should -Be 'Computer1'
            $result.PrimaryUser | Should -Be 'John Doe'
            $result.ServiceTag | Should -Be 'ABC1234'
            $result.InstallDate | Should -Be 'Deployed 2023-05-10'
        }
    }

    Context "With missing description" {
        It "Returns object with empty properties" {
            # Define test input
            $computerObject = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADComputer -Property @{
                Description = $null
            }
            $computerObject['Name'].Add('Computer2') | Out-Null

            # Call the function
            $result = Get-ParsedDescriptionData -ComputerObject $computerObject

            # Assert the result is correct
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain "ComputerDescription"
            $result.Name | Should -Be 'Computer2'
            $result.Source | Should -Be 'Parsed'
            $result.PrimaryUser | Should -BeNullOrEmpty
            $result.ServiceTag | Should -BeNullOrEmpty
            $result.InstallDate | Should -BeNullOrEmpty
        }
    }

    Context "With invalid object type" {
        It "Throws an error" {
            # Define test input
            $invalidComputerObject = "InvalidObject"

            # Call the function and capture the error
            $error = $null
            try {
                Get-ParsedDescriptionData -ComputerObject $invalidComputerObject -ErrorAction Stop
            }
            catch {
                $error = $_.Exception.Message
            }

            # Assert the error message
            $error | Should -Match "Microsoft.ActiveDirectory.Management.ADComputer or Selected.Microsoft.ActiveDirectory.Management.ADComputer"
        }
    }
}
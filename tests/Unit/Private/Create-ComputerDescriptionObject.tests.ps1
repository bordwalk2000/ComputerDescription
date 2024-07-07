BeforeAll {
    . $PSCommandPath.Replace('tests\Unit', 'source').Replace('tests.ps1', 'ps1')
}

Describe "Create-ComputerDescriptionObject" {
    Context "With valid input" {
        It "Creates a ComputerDescription object" {
            # Define test input
            $descriptionString = "John Doe | ABC1234 | Deployed 2023-05-10"

            # Call the function
            $result = Create-ComputerDescriptionObject -DescriptionString $descriptionString

            # Assert the object is created & PSTypeNames Contains 'ComputerDescription'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'

            # Assert properties are set correctly
            $Result.PrimaryUser | Should -Be 'John Doe'
            $Result.ServiceTag | Should -Be 'ABC1234'
            $Result.InstallDate | Should -Be 'Deployed 2023-05-10'
        }
    }

    Context "With AssetTagRegex specified" {
        It "Creates a ComputerDescription object" {
            # Define test input
            $descriptionString = "John Doe | ABC1234 | C00001 | Deployed 2023-05-10"

            # Call the function
            $result = Create-ComputerDescriptionObject -DescriptionString $descriptionString -AssetTagRegex '^[C]\d{5}$'

            # Assert the object is created & PSTypeNames Contains 'ComputerDescription'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'

            # Assert properties are set correctly
            $Result.PrimaryUser | Should -Be 'John Doe'
            $Result.ServiceTag | Should -Be 'ABC1234'
            $Result.AssetTag | Should -Be 'C00001'
            $Result.InstallDate | Should -Be 'Deployed 2023-05-10'
        }
    }

    Context "With empty input" {
        It "Creates a ComputerDescription object with empty properties" {
            # Define test input
            $descriptionString = ""

            # Call the function
            $result = Create-ComputerDescriptionObject -DescriptionString $descriptionString

            # Assert the object is created & PSTypeNames Contains 'ComputerDescription'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'

            # Assert properties are set correctly
            $Result.PrimaryUser | Should -Be ''
            $Result.ServiceTag | Should -Be ''
            $Result.InstallDate | Should -Be ''
        }
    }

    Context "With limited input" {
        It "Creates a ComputerDescription object with only PrimaryUser" {
            # Define test input
            $descriptionString = "John Doe"

            # Call the function
            $result = Create-ComputerDescriptionObject -DescriptionString $descriptionString

            # Assert the object is created & PSTypeNames Contains 'ComputerDescription'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeNames | Should -Contain 'ComputerDescription'

            # Assert properties are set correctly
            $Result.PrimaryUser | Should -Be 'John Doe'
            $Result.ServiceTag | Should -Be ''
            $Result.InstallDate | Should -Be ''
        }
    }
}

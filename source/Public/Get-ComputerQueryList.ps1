<#
.SYNOPSIS
    Retrieves a list of AD computer objects based on specified computer names or organizational units.

.DESCRIPTION
    The Get-ComputerQueryList function queries Active Directory to retrieve computer objects.
    You can specify a list of computer names or organizational units to search for enabled computers.
    The function returns a unique list of computer names and their descriptions.

.PARAMETER Name
    A list of computer names to search for in Active Directory.
    This parameter accepts values from the pipeline or pipeline by property name.

.PARAMETER OUPath
    A list of organizational unit paths to search for computers.
    Each OU path is validated to ensure it exists in Active Directory.

.EXAMPLE
    PS C:\> Get-ComputerQueryList -Name "PC01", "PC02"

    Retrieves information for the specified computers "PC01" and "PC02" from Active Directory.

.EXAMPLE
    PS C:\> Get-ADComputer -Filter * | Get-ComputerQueryList

    Retrieves information for all computers in Active Directory.

.EXAMPLE
    PS C:\> Get-ComputerQueryList -OUPath "OU=OU1,DC=example,DC=com", "OU=OU2,DC=example,DC=com"

    Retrieves information for all enabled computers within the specified OU.

.NOTES
    - This function requires the Active Directory module.
    - Ensure you have the necessary permissions to query AD computer objects.
    - The function filters for enabled computers when querying by OU.

#>
Function Get-ComputerQueryList {
    [CmdletBinding(
        PositionalBinding = $false
    )]
    param(
        # List of Computer Name
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [String[]]
        $Name,

        # Specify OU Lists you want to search
        [Parameter()]
        [ValidateScript(
            {
                [bool](Get-ADOrganizationalUnit -Identity $_)
            }
        )]
        [string[]]
        $OUPath
    )

    begin {
        $QueryComputerList = @()
    }

    process {
        if ($OUPath) {
            $QueryComputerList = $OUPath |
                ForEach-Object {
                    Get-ADComputer -Filter { Enabled -eq "True" } -Properties Description -SearchBase $_
                }
        }

        if ($Name) {
            foreach ($Computer in $Name) {
                try {
                    $QueryComputerList += Get-ADComputer -Identity $Computer -Properties Description
                }
                catch {
                    Write-Error -Message "Cannot find computer name of '$Computer' on the domain."
                }
            }
        }
    }

    end {
        return $QueryComputerList
        | Select-Object Name, Description -Unique
        | Sort-Object Name
    }
}
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
        [Alias("Name")]
        [String[]]
        $ComputerName,

        # Specify OU Lists you want to search
        [Parameter()]
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

        if ($ComputerName) {
            foreach ($Computer in $ComputerName) {
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
        $QueryComputerList | Select-Object -Unique | Sort-Object Name
    }
}
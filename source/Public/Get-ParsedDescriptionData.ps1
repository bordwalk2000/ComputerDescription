Function Get-ParsedDescriptionData {
    [CmdletBinding()]
    param(
        # List of Computer Name
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0
        )]
        $ComputerObject,

        # AssetTag Regex
        [Parameter()]
        [String]
        $AssetTagRegex,

        # ServiceTag Regex
        [Parameter()]
        [String]
        $ServiceTagRegex
    )

    begin {
        # "Define Params for Get-ParsedDescriptionData"
        $params = @{
            AssetTagRegex   = $AssetTagRegex
            ServiceTagRegex = $ServiceTagRegex
        }

        # Remove empty items from params
        foreach ($Key in @($params.Keys)) {
            if (-not $params[$Key]) {
                $params.Remove($Key)
            }
        }
    }

    process {
        # Check if Object type is Type Microsoft.ActiveDirectory.Management.ADComputer'
        if (
            @(
                'Microsoft.ActiveDirectory.Management.ADComputer',
                'Selected.Microsoft.ActiveDirectory.Management.ADComputer'
            ) -notcontains ($ComputerObject | Get-Member)[0].TypeName
        ) {
            $Message = "Type needs to be type Microsoft.ActiveDirectory.Management.ADComputer " +
            "or Selected.Microsoft.ActiveDirectory.Management.ADComputer"
            Write-Error -Message $Message -ErrorAction Stop
        }

        ForEach-Object -InputObject $ComputerObject {
            Write-Verbose  "Converting computer description for $($_.Name)"
            $Object = New-Object PSObject -Property @{
                PSTypeName = 'ComputerDescription'
                Name       = $_.Name
                Source     = 'Parsed'
            }

            # Check to see if AD Object has a description that was able to be pulled.
            if ($_.Description) {
                (
                    # Call function to parsed computer description & return object
                    Create-ComputerDescriptionObject -DescriptionString $_.Description @params
                ).PSObject.Members |
                    Where-Object MemberType -eq 'NoteProperty' |
                        Foreach-Object {
                            # Adds each one of the object's note returned to the $Object variable
                            $Object | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -ErrorAction SilentlyContinue
                        }
            }
        }

        # Write $Object to the pipeline.
        Write-Output $Object
    }
}
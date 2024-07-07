<#
.SYNOPSIS
    Parses the description data of Active Directory computer objects.

.DESCRIPTION
    The Get-ParsedDescriptionData function processes a list of Active Directory computer objects,
    extracting and parsing description data according to specified regular expressions for asset tags and service tags.

.PARAMETER ComputerObject
    The Active Directory computer object(s) to be processed.
    This parameter is mandatory and accepts values from the pipeline.

.PARAMETER AssetTagRegex
    The regular expression pattern used to extract asset tags from the computer description.

.PARAMETER ServiceTagRegex
    The regular expression pattern used to extract service tags from the computer description.

.EXAMPLE
    PS C:\> Get-ADComputer -Filter * | Get-ParsedDescriptionData -AssetTagRegex "^[C]\d{5}$" -ServiceTagRegex "\w{7}"

    Retrieves all computer objects from AD and parses their descriptions using the provided regex patterns.

.EXAMPLE
    PS C:\> $computers = Get-ADComputer -Filter *; $computers | Get-ParsedDescriptionData -AssetTagRegex "^[C]\d{5}$"

    Parses the description of the given computer objects using the specified asset tag regex pattern.

.NOTES
    - The function requires the input objects to be of type Microsoft.ActiveDirectory.Management.ADComputer.
    - Ensure you have appropriate permissions to query Active Directory and read the description property of computer objects.

#>
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
        $regexParams = @{
            AssetTagRegex   = $AssetTagRegex
            ServiceTagRegex = $ServiceTagRegex
        }

        # Remove empty items from params
        foreach ($Key in @($regexParams.Keys)) {
            if (-not $regexParams[$Key]) {
                $regexParams.Remove($Key)
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
            Write-Debug "Description String: $($_.description)"
            $Object = New-Object PSObject -Property @{
                PSTypeName = 'ComputerDescription'
                Name       = $_.Name
                Source     = 'Parsed'
            }

            # Check to see if AD Object has a description that was able to be pulled.
            if ($_.Description) {
                (
                    # Call function to parsed computer description & return object
                    Create-ComputerDescriptionObject -DescriptionString $_.Description @regexParams
                ).PSObject.Members
                | Where-Object MemberType -eq 'NoteProperty'
                | Foreach-Object {
                    # Adds each one of the object's note returned to the $Object variable
                    $params = @{
                        MemberType  = 'NoteProperty'
                        Name        = $_.Name
                        Value       = $_.Value
                        ErrorAction = 'SilentlyContinue'
                    }
                    $Object | Add-Member @params
                }
            }
        }

        # Write $Object to the pipeline.
        Write-Output $Object
    }
}
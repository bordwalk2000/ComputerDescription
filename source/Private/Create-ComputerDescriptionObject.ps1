<#
.SYNOPSIS
    Creates a computer description object by parsing a description string.

.DESCRIPTION
    The Create-ComputerDescriptionObject function processes a description string,
    extracting and assigning values such as PrimaryUser, ServiceTag, AssetTag, and InstallDate
    to a new PSObject. It uses regular expressions to identify and validate the ServiceTag and AssetTag.

.PARAMETER DescriptionString
    The description string to be parsed. This parameter accepts values from the pipeline.

.PARAMETER AssetTagRegex
    The regular expression pattern used to extract asset tags from the description string.

.PARAMETER ServiceTagRegex
    The regular expression pattern used to extract service tags from the description string.
    Defaults to a regex pattern for Dell Service Tags, which matches any uppercase letter (A-Z) or digit (0-9) and is 7 characters long.

.EXAMPLE
    PS C:\> "JohnDoe | ABC1234 | 2021-07-06" | Create-ComputerDescriptionObject -AssetTagRegex "ABC\d{4}"

    Parses the description string and returns a ComputerDescription object with the extracted properties.

.EXAMPLE
    PS C:\> Create-ComputerDescriptionObject -DescriptionString "JohnDoe | ABC1234 | 2021-07-06" -AssetTagRegex "ABC\d{4}"

    Parses the provided description string and returns a ComputerDescription object with the extracted properties.

.NOTES
    - Ensure the description string is properly formatted with expected delimiters and data.
    - The function will attempt to parse the description string based on the provided regex patterns for asset tags and service tags.

#>
Function Create-ComputerDescriptionObject {
    [CmdletBinding()]
    param(
        # DescriptionString
        [Parameter(
            ValueFromPipeline,
            Position = 0
        )]
        [String]
        $DescriptionString,

        # AssetTag Regex
        [Parameter()]
        [String]
        $AssetTagRegex,

        # ServiceTag Regex
        [Parameter()]
        [String]
        # Defaults to Dell Service Tag Regex
        # Matches any uppercase letter (A-Z) or any digit (0-9) & 7 characters long.
        $ServiceTagRegex = '^([A-Z0-9]){7}$'
    )

    process {
        $Object = New-Object PSObject -Property @{
            PSTypeName  = 'ComputerDescription'
            PrimaryUser = ''
            ServiceTag  = ''
            AssetTag    = ''
            InstallDate = ''
            Description = $DescriptionString
            Source      = 'Parsed'
        }

        # Split description filed on Pipe & Trim results
        $DescriptionSplit = $DescriptionString.Split('|').trim()

        ## PrimaryUser ##
        # Check to see if split returned multiple array and assigned first object in array to PrimaryUser variable.
        $PrimaryUser = if ($DescriptionSplit.count -gt 1) {
            $DescriptionSplit[0]
        }
        else {
            # Otherwise if no Pipes found in description, set that to PrimaryUser variable.
            $DescriptionSplit
        }

        if (
            # Checks to make sure PrimaryUser property doesn't contain a number.
            $PrimaryUser -notmatch "[0-9]" -and
            # Checks to makes sure PrimaryUser property does not contain all capitalized letters.
            $PrimaryUser -cnotmatch "^[A-Z]+$"
        ) {
            # Sets $Object's PrimaryUser filed to be the found PrimaryUser
            $Object.PrimaryUser = $PrimaryUser
        }

        # Loop though rest of DescriptionSplit array to match up other objects.
        $DescriptionSplit
        | Where-Object { $_ -ne $DescriptionSplit[0] }
        | ForEach-Object {
            # Verify a value is in the array
            if (![string]::IsNullOrEmpty($_)) {

                ## ServiceTag ##
                if ($_ -match $ServiceTagRegex) {
                    # Sets $Object's ServiceTag filed to be the found ServiceTag
                    $Object.ServiceTag = $_
                }

                ## AssetTag ##
                if ($AssetTagRegex -and $_ -match $AssetTagRegex) {
                    # Sets $Object's AssetTag filed to be the found AssetTag
                    $Object.AssetTag = $_
                }
            }

            ## InstallDate ##
            if (
                # Check if DescriptionSplit array contains either 'Deployed' or 'Reinstalled' in one of the splits.
                @("Deployed", "Reinstalled") -contains $_.Split(' ')[0]
            ) {
                if ($_.Split(' ').count -eq 2) {
                    # Checks to see if found date can be converted to actual date
                    if ([Boolean][DateTime]::Parse($_.Split(' ')[-1])) {
                        # Sets $Object's InstallDate filed to be the found InstallDate
                        $Object.InstallDate = $_
                    }
                }
            }
        }

        return $Object
    }

}
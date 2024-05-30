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
        $DescriptionSplit | Where-Object { $_ -ne $DescriptionSplit[0] } | ForEach-Object {
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
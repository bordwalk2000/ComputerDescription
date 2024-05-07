Function Convert-ComputerDescription {
    [CmdletBinding()]
    param(
        # List of Computer Name
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0
        )]
        $Identity
    )

    process {
        # Check if Object type is Type Microsoft.ActiveDirectory.Management.ADComputer'

        if ($Identity.GetType().FullName -ne 'Microsoft.ActiveDirectory.Management.ADComputer') {
            Write-Error "Type needs to be Microsoft.ActiveDirectory.Management.ADComputer"
            Break
        }

        ForEach-Object -InputObject $Identity {
            Write-Verbose  "Converting computer description for $($Computer.Name)"
            $Object = New-Object PSObject -Property @{
                PSTypeName  = 'ComputerDescription'
                Name        = $_.Name
                PrimaryUser = ''
                ServiceTag  = ''
                AssetTag    = ''
                InstallDate = ''
                Description = $_.Description
            }

            # Check to see if AD Object has a description that was able to be pulled.
            if ($_.Description) {
                # Split description filed on Pipe & Trim results
                $DescriptionSplit = $_.Description.Split('|').trim()

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
                    $PrimaryUser -notmatch "[0-9]" -or
                    # Checks to makes sure PrimaryUser property does not contain all capitalized letters.
                    $PrimaryUser -cnotmatch "[^A-Z]"
                ) {
                    # Sets $Object's PrimaryUser filed to be the found PrimaryUser
                    $Object.PrimaryUser = $PrimaryUser
                }

                # Loop though rest of DescriptionSplit array to match up other objects.
                $DescriptionSplit | Where-Object { $_ -ne $DescriptionSplit[0] } | ForEach-Object {
                    # Verify a value is in the array
                    if (![string]::IsNullOrEmpty($_)) {
                        ## ServiceTag ##
                        if (
                            -not(
                                $Object.AssetTag -and
                                $_.Substring(1) -cmatch "[^A-Z]" -and
                                $_ -match "[0-9]" -and
                                $_.Length -eq 7
                            )
                        ) {
                            # Sets $Object's ServiceTag filed to be the found ServiceTag
                            $Object.ServiceTag = $_

                        }
                        ## AssetTag ##
                        elseif (
                            $_ -clike "C00*" -and
                            $_ -match "[0-9]" -and
                            (
                                $_.Length -eq 6 -or
                                $_.Length -eq 28
                            )
                        ) {
                            # Sets $Object's AssetTag filed to be the found AssetTag
                            $Object.AssetTag = $_

                        }
                        ## InstallDate ##
                        elseif (
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
                }
            }
        }

        # Write $Object to the pipeline.
        Write-Output $Object
    }
}

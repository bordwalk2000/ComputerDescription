<#
.SYNOPSIS
    Updates the description field of Active Directory computer objects based on provided data.

.DESCRIPTION
    The Update-ADComputerDescription function allows administrators to update the description field
    of Active Directory computer objects.
    The function can use parsed or pulled computer description data, or a list of computer names and
    organizational units.
    It supports dynamically required parameters when the AssetTagSupport switch is used.

.PARAMETER ParsedComputerDescriptionList
    A list of parsed computer description data objects. The data source must be "Parsed".

.PARAMETER PulledComputerDescriptionList
    A list of pulled computer description data objects. The data source must be "Pulled".

.PARAMETER ComputerName
    A list of computer names to update. This parameter can be provided via pipeline input.

.PARAMETER OUPath
    A list of OU paths to search for computers. This parameter requires valid OUs.

.PARAMETER AssetTagSupport
    A switch to enable asset tag support, requiring the AssetTagRegex parameter to be specified.

.PARAMETER ServiceTagRegex
    A regular expression to match service tags.

.PARAMETER AssetTagRegex
    (Dynamic) A regular expression to match asset tags. This parameter is mandatory if AssetTagSupport is specified.

.EXAMPLE
    PS C:\> Update-ADComputerDescription -ParsedComputerDescriptionList $parsedData

    Updates the AD computer descriptions using the parsed data.

.EXAMPLE
    PS C:\> Get-ADComputer -Filter * | Update-ADComputerDescription -OUPath "OU=Computers,DC=example,DC=com"

    Updates the AD computer descriptions for all computers in the specified OU.

.EXAMPLE
    PS C:\> Update-ADComputerDescription -ComputerName "PC01", "PC02" -ServiceTagRegex '^[C]\d{5}$'

    Updates the AD computer descriptions for specified computers with service tags matching the regex.

.EXAMPLE
    PS C:\> Get-ComputerQueryList -OUPath "OU=No_Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com" |
    Get-ParsedDescriptionData -AssetTagRegex '^[C]\d{5}$' | Update-ADComputerDescription

    Updates the AD computer descriptions for specified computers with service tags matching the regex.

.EXAMPLE
    PS C:\> Get-DescriptionDataFromComputer -ComputerName (
        Get-ComputerQueryList -OUPath "OU=Computers,OU=OU1,DC=example,DC=com"
    ).Name -Verbose -Debug -ThrottleLimit 1 | Update-ADComputerDescription -AssetTagSupport -AssetTagRegex '^[C]\d{5}$'

    Updates the AD computer descriptions for specified computers with service tags matching the regex.

.EXAMPLE
    PS C:\> Update-ADComputerDescription -ParsedComputerDescriptionList (
        Get-ComputerQueryList -OUPath "OU=Computers,OU=OU1,DC=example,DC=com", "OU=Laptops,OU=OU2,DC=example,DC=com"
        | Get-ParsedDescriptionData -AssetTagRegex '^[C]\d{5}$'
    ) -AssetTagSupport -AssetTagRegex '^[C]\d{5}$' -Verbose -Debug

    Updates the AD computer descriptions for specified computers with service tags matching the regex.

.NOTES
    - This function requires the Active Directory module.
    - Ensure you have the necessary permissions to update AD computer objects.
    - If using the AssetTagSupport switch, the AssetTagRegex parameter becomes mandatory.
#>
Function Update-ADComputerDescription {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    param(
        [Parameter(
            ParameterSetName = "ComputerDescription",
            HelpMessage = 'Parsed ComputerDescription data object.'
        )]
        [ValidateScript(
            {
                $_.Source -eq "Parsed"
            }
        )]
        [System.Management.Automation.PSTypeName('ComputerDescription')]
        $ParsedComputerDescriptionList,

        [Parameter(
            ParameterSetName = "ComputerDescription",
            HelpMessage = 'Pulled ComputerDescription data object.'
        )]
        [ValidateScript(
            {
                $_.Source -eq "Pulled"
            }
        )]
        [System.Management.Automation.PSTypeName('ComputerDescription')]
        $PulledComputerDescriptionList,

        # List of Computer Name
        [Parameter(
            ParameterSetName = "ComputerList",
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias("Name")]
        [String[]]
        $ComputerName,

        # Specify OU Lists you want to search
        [Parameter(
            ParameterSetName = "ComputerList"
        )]
        [ValidateScript(
            {
                [bool](Get-ADOrganizationalUnit -Identity $_)
            }
        )]
        [string[]]
        $OUPath,

        # AssetTag Support
        [Parameter()]
        [Switch]
        $AssetTagSupport,

        # ServiceTag Regex
        [Parameter()]
        [String]
        $ServiceTagRegex
    )

    dynamicParam {
        # This dynamic parameter creation is used because AssetTagRegex needs to be specified if -AssetTagSupport switch is called
        if ($AssetTagSupport) {
            Write-Verbose "Building dynamic parameters"
            $AssetTagRegex = New-Object System.Management.Automation.ParameterAttribute
            $AssetTagRegex.Mandatory = $true
            $AssetTagRegex.HelpMessage = "Please enter the number of minutes your account needs to be elevated for: "
            $AssetTagRegexAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AssetTagRegexAttributeCollection.Add($AssetTagRegex)
            $AssetTagRegexParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'AssetTagRegex', [String], $AssetTagRegexAttributeCollection
            )

            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('AssetTagRegex', $AssetTagRegexParam)
            return $paramDictionary
        }
    }

    begin {
        # Print currently choice parameter set
        Write-Verbose "Selected ParameterSet: $($PSCmdlet.ParameterSetName)"

        # Define Params used in Get-ParsedDescriptionData Function
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

        # Process ComputerList ParameterSetName
        if ($PSCmdlet.ParameterSetName -eq "ComputerList") {
            # "Define Params for Get-ComputerQueryList"
            $params = @{
                ComputerName = $ComputerName
                OUPath       = $OUPath
            }

            # Remove empty items from params
            foreach ($Key in @($params.Keys)) {
                if (-not $params[$Key]) {
                    $params.Remove($Key)
                }
            }

            # Get List of Computers to query using AD Data
            Write-Verbose "Pulling List of Computers from AD"
            $ComputerList = Get-ComputerQueryList @params

            # If Get-ComputerQueryList Function returned Results.
            if ($ComputerList) {
                # Grab the data on the found computers.
                Write-Debug "Found ComputerList: $($ComputerList | Out-String)"
                $ParsedComputerDescriptionList = $ComputerList | Get-ParsedDescriptionData @regexParams
                Write-Debug "Found ParsedComputerDescriptionList: $($ParsedComputerDescriptionList | Out-String)"

                Get-DescriptionDataFromComputer -ComputerName $ComputerList.Name -OutVariable PulledComputerDescriptionList
                Write-Debug "Found PulledComputerDescriptionList: $($PulledComputerDescriptionList | Out-String)"
            }
            else {
                Write-Verbose "No results was returned by the Get-ComputerQueryList function using the following params."
                Write-Verbose "Params $($params | Out-String)"
                $Message = "Unable to find any computers specified.  Please check your Parameters and try again."
                Write-Error -Message $Message -ErrorAction Stop
            }
        }

        # Process ComputerDescription ParameterSetName
        if ($PSCmdlet.ParameterSetName -eq "ComputerDescription") {
            # Grab Missing PulledComputerDescriptionList using ParsedComputerDescriptionList Variable Data
            if (
                $ParsedComputerDescriptionList -and
                -not($PulledComputerDescriptionList)
            ) {
                Write-Verbose "Pulling PulledComputerDescriptionList Data using Names from ParsedComputerDescriptionList."
                $params = @{
                    ComputerName = $ParsedComputerDescriptionList.Name
                }
                $Results = Get-DescriptionDataFromComputer @params

                # Check for returned data to prevent MetadataError when trying to assign to PulledComputerDescriptionList
                if ($Results.count -gt 0) {
                    $PulledComputerDescriptionList = $Results
                }
            }

            # Grab Missing ParsedComputerDescriptionList using PulledComputerDescriptionList Variable Data
            if (
                $PulledComputerDescriptionList -and
                -not($ParsedComputerDescriptionList)
            ) {
                Write-Verbose "Pulling ParsedComputerDescriptionList Data using Names from PulledComputerDescriptionList."
                $ParsedComputerDescriptionList = $PulledComputerDescriptionList
                | Get-ComputerQueryList
                | Get-ParsedDescriptionData @regexParams
            }
        }

        # Throw Error if either one of the ComputerDescriptionList Variables are empty.
        if (
            -not($ParsedComputerDescriptionList) -or
            -not($PulledComputerDescriptionList)
        ) {
            Write-Verbose "One or both of the ComputerDescriptionList variables were unable to be populated."
            Write-Debug "ParsedComputerDescriptionList Count: $($ParsedComputerDescriptionList.count)"
            Write-Debug "PulledComputerDescriptionList Count: $($PulledComputerDescriptionList.count)"
            Write-Error $([string]::Join(
                    "`n",
                    "At least one of the ComputerDescriptionList variables was unable to grab required data.",
                    "Fix the is with missing data and run the function again."
                ))
            break
        }
    }

    process {
        # Fetching PulledComputerDescriptionList first because if no New data then no reason to check description.
        Write-Verbose "Starting Processing PulledComputerDescriptionList"
        Write-Debug "PulledComputerDescriptionList Values: $($PulledComputerDescriptionList | Out-String)"
        ForEach ($Computer in $PulledComputerDescriptionList) {
            # Create an array for the data.
            if ($AssetTagSupport) {
                $array = @(
                    $Computer.PrimaryUser,
                    $Computer.ServiceTag,
                    $Computer.AssetTag.trim()
                    $Computer.InstallDate
                )
            }
            else {
                $array = @(
                    $Computer.PrimaryUser,
                    $Computer.ServiceTag,
                    $Computer.InstallDate
                )
            }

            # Concatenate $array to create AD description.
            $ConcatenatedDescriptionData = [String]::Join(" | ", $array)

            Write-Debug "ConcatenatedDescriptionData for $($Computer.Name): '$ConcatenatedDescriptionData'"

            # Try to find corresponding ComputerName in ParsedComputerDescriptionList list.
            if (
                $ParsedComputerDescriptionList
                | Where-Object { $_.Name -eq $Computer.Name }
                | Tee-Object -Variable ParsedComputerObject
            ) {
                # Preform checks for to see if we have more up-to-date data and ask user if we want to update the description in AD.
                if (
                    # Makes sure $ConcatenatedDescriptionData does not match the description already in AD.
                    $ConcatenatedDescriptionData -ne $ParsedComputerObject.Description -and
                    # Ask the user to confirm changing the AD computer description.
                    $PSCmdlet.ShouldProcess(
                        $ParsedComputerObject.Name,
                        "Updated description from '$($ParsedComputerObject.Description)' to '$ConcatenatedDescriptionData'"
                    )
                ) {
                    # Update the AD computer object's description.
                    try {
                        Write-Verbose "Updating $($Computer.Name) Description from '$($ParsedComputerObject.Description)' to '$ConcatenatedDescriptionData'"
                        Set-ADComputer -Identity $Computer.Name -Description $ConcatenatedDescriptionData
                    }
                    catch {
                        Write-Error "Unable to set computer description for $($Computer.Name). `n$_"
                    }
                }
                else {
                    Write-Output "No Updates made to $($Computer.Name)."
                }
            }
        }
    }
}
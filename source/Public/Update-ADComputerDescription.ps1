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
            Return $paramDictionary
        }
    }

    begin {
        # Print currently choice parameter set
        Write-Verbose "Selected ParameterSet: $($PSCmdlet.ParameterSetName)"

        # Define Params used in Get-ParsedDescriptionData Function
        $ParsedParams = @{
            AssetTagRegex   = $AssetTagRegex
            ServiceTagRegex = $ServiceTagRegex
        }

        # Remove empty items from params
        foreach ($Key in @($ParsedParams.Keys)) {
            if (-not $ParsedParams[$Key]) {
                $ParsedParams.Remove($Key)
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
                $ParsedComputerDescriptionList = $ComputerList | Get-ParsedDescriptionData @ParsedParams
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
                $PulledComputerDescriptionList = Get-DescriptionDataFromComputer -ComputerName $ParsedComputerDescriptionList.Name
                Create-ComputerDescriptionObject -ComputerName
            }

            # Grab Missing ParsedComputerDescriptionList using PulledComputerDescriptionList Variable Data
            if (
                $PulledComputerDescriptionList -and
                -not($ParsedComputerDescriptionList)
            ) {
                Write-Verbose "Pulling ParsedComputerDescriptionList Data using Names from PulledComputerDescriptionList."
                # TODO: I Should be able ot use just the PulledComputerDescription Data for this.

                $ParsedComputerDescriptionList = Get-ComputerQueryList $PulledComputerDescriptionList |
                    Get-ParsedDescriptionData @ParsedParams
            }
        }

        # Throw Error if either one of the ComputerDescriptionList Variables are empty.
        if (
            -not($ParsedComputerDescriptionList) -or
            -not($PulledComputerDescriptionList)
        ) {
            Write-Verbose "One or both of the ComputerDescriptionList variables was able to be populated."
            Write-Error "Unable to find a ComputerDescriptionList to pull data from."
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
                $ParsedComputerDescriptionList |
                    Where-Object { $_.Name -eq $Computer.Name } |
                        Tee-Object -Variable ParsedComputerObject
            ) {
                # Preform checks for to see if we have more up-to-date data and ask user if we want to update the description in AD.
                if (
                    # Makes sure $ConcatenatedDescriptionData does not match the description already in AD.
                    $ConcatenatedDescriptionData -ne $ParsedComputerObject.Description -and
                    # Ask the user to confirm changing the AD computer description.
                    $PSCmdlet.ShouldProcess(
                        $_.Name,
                        "Updated description from '$($ParsedComputerObject.Description)' to '$ConcatenatedDescriptionData'"
                    )
                ) {
                    # Update the AD computer object's description.
                    try {
                        Write-Verbose "Updating $($Computer.Name) Description from '$($Computer.Description)' to '$ConcatenatedDescriptionData'"
                        Set-ADComputer -Identity $Computer.Name -Description $ConcatenatedDescriptionData
                    }
                    catch {
                        Write-Error "Unable to set computer description for $($Computer.Name)."
                        Write-Error $($_.Exception.Message)
                    }
                }
                else {
                    Write-Output "No Updates made to $($Computer.Name)."
                }
            }
        }
    }
}
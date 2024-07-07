<#
.SYNOPSIS
    Retrieves description data from specified computers.

.DESCRIPTION
    The Get-DescriptionDataFromComputer function connects to specified computers, retrieves various
    pieces of description data such as Primary User, Service Tag, Asset Tag, and Install Date, and
    outputs an object containing this data.

.PARAMETER ComputerName
    A list of computer names to query data from.
    This parameter is mandatory and accepts values from the pipeline or by property name.

.PARAMETER ThrottleLimit
    Specifies the number of concurrent jobs that can be run at one time.
    The default value is 5.

.EXAMPLE
    PS C:\> "PC1", "PC2" | Get-DescriptionDataFromComputer

    Retrieves description data from the specified computers "PC1" and "PC2".

.EXAMPLE
    PS C:\> Get-DescriptionDataFromComputer -ComputerName "PC1", "PC2" -ThrottleLimit 10

    Retrieves description data from the specified computers with a throttle limit of 10 concurrent jobs.

.EXAMPLE
    PS C:\> Get-ADComputer -Filter * | Get-DescriptionDataFromComputer

    Retrieves description data from all computers in Active Directory.

.NOTES
    - This function requires the Active Directory and CIM cmdlets.
    - Ensure you have the necessary permissions to query the computer objects.
    - The function checks if each computer is online before attempting to retrieve data.
    - The retrieved data includes Primary User, Service Tag, Asset Tag, and Install Date.

#>
Function Get-DescriptionDataFromComputer {
    [CmdletBinding()]
    param(
        # List of Computers to query data from
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position = 0
        )]
        [Alias("Name")]
        [string[]]
        $ComputerName,

        [Parameter(
            HelpMessage = "How many jobs will be ran at one time."
        )]
        [int]
        $ThrottleLimit = 5
    )
    begin {
        # Code that will be during the different jobs that will be created.
        $ScriptBlock = {
            # Import-Module .\output\module\ComputerDescription\0.0.1\ComputerDescription.psd1

            foreach ($Computer in $Args) {
                # Set Computer variable to be in all caps.
                $Computer = $Computer.ToUpper()

                # Check to see if able to connect to the machine.
                if (-not(Test-Connection -TargetName $Computer -Count 2 -Quiet)) {
                    # Write error & start processing next item in the foreach loop.
                    Write-Error "$Computer is Offline"
                    continue
                }

                # Create Object that will contain the returned computer data.
                $Object = New-Object PSObject -Property @{
                    PSTypeName  = 'ComputerDescription'
                    Name        = $Computer
                    PrimaryUser = ''
                    ServiceTag  = ''
                    AssetTag    = ''
                    InstallDate = ''
                    Description = $null
                    Source      = 'Pulled'
                }

                Write-Verbose "$Computer is Online, Start process to pull data from $Computer."

                ## PrimaryUser ##
                try {
                    Write-Verbose "Calling Get-PrimaryUser Function for $Computer"
                    $Object.PrimaryUser = Get-PrimaryUser $Computer
                    Write-Debug "PrimaryUserName Results: $($Object.PrimaryUser)"
                }
                catch {
                    $Message = "Unable to access Get-WinEvent on $Computer & therefore unable to pull PrimaryUser data."
                    Write-Error -Message "$Message `n$_"
                    continue
                }

                if ($Object.PrimaryUser) {
                    try {
                        # Check to see if username is in Active Directory
                        $Object.PrimaryUser = (Get-ADuser $Object.PrimaryUser.split('\')[-1]).Name
                    }
                    catch {
                        Write-Verbose "Unable to find ADuser for $($Object.PrimaryUser)."
                    }
                }


                ## ServiceTag ##
                try {
                    $Object.ServiceTag = (Get-CimInstance Win32_BIOS -ComputerName $Computer -ErrorAction Stop).SerialNumber

                    # Specify VMware VM if service tag says vmware.
                    if ($ServiceTag -match "vmware") {
                        $Object.ServiceTag = 'VMWare VM'
                    }
                }
                catch {
                    $Message = "Unable to access Get-CimInstance Win32_BIOS on $Computer & therefor unable to pull ServiceTag data."
                    Write-Error -Message "$Message `n$_"
                    continue
                }


                ## AssetTag ##
                try {
                    $Object.AssetTag = (
                        Get-CimInstance Win32_SystemEnclosure -ComputerName $Computer -ErrorAction Stop
                    ).SMBiosAssetTag.split(' ')[0].ToUpper()
                    Write-Debug "SMBiosAssetTag Results: $($Object.AssetTag)"
                }
                catch {
                    $Message = "Unable to access Get-CimInstance Win32_SystemEnclosure on $Computer & therefor unable to pull AssetTag data."
                    Write-Error -Message "$Message `n$_"
                    continue
                }


                ## InstallDate ##
                try {
                    $Object.InstallDate = "Deployed " + (
                        Get-CimInstance Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop
                    ).InstallDate.ToString("yyyy-MM-dd")
                    Write-Debug "InstallDate Results: $($Object.InstallDate)"
                }
                catch {
                    $Message = "Unable to access Get-CimInstance Win32_OperatingSystem on $Computer & therefor unable to pull InstallDate data."
                    Write-Error -Message "$Message `n$_"
                    continue
                }

                Write-Output $Object
            }
        }

        # Define JobList array.
        $JobList = @()
    }

    process {
        # Starts creating jobs when they are passed to the pipeline as they come in.
        foreach ($Computer in $ComputerName) {
            $params = @{
                Name          = $Computer
                ScriptBlock   = $ScriptBlock
                ArgumentList  = $Computer
                ThrottleLimit = $ThrottleLimit
            }
            $JobList += Start-ThreadJob @params
        }
    }

    end {
        # Removing Wait-Job allows the jobs to go on to the next pipeline as soon as that job finishes.
        return $JobList
        | Receive-Job -Wait
    }
}
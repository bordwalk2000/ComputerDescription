Function Get-DescriptionDataFromComputer {
    [CmdletBinding()]
    param(
        # List of Computers to query data from
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0
        )]
        [string[]]
        $ComputerName
    )

    process {
        foreach ($Computer in $ComputerName) {
            # Set Computer variable to be in all caps.
            $Computer = $Computer.ToUpper()

            # Check to see if able to connect to the machine.
            if (-not(Test-Connection -TargetName $Computer -Count 2 -Quiet)) {
                Write-Error "$Computer is Offline"
                Break
            }

            $Object = New-Object PSObject -Property @{
                PSTypeName  = 'ComputerDescription'
                Name        = $Computer
                PrimaryUser = ''
                ServiceTag  = ''
                AssetTag    = ''
                InstallDate = ''
                Description = $null
            }

            Write-Verbose "$Computer is Online, Start process to pull data from $Computer."

            ## PrimaryUser ##
            try {
                Write-Verbose "Calling Get-PrimaryUser Function for $Computer"
                Write-Debug "Get-PrimaryUser $Computer"
                $Object.PrimaryUser = Get-PrimaryUser $Computer
                Write-Debug "PrimaryUserName Results: $($Object.PrimaryUser)"
            }
            catch {
                Write-Error "Unable to access Get-WinEvent on $Computer & therefor unable to pull PrimaryUser data."
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
                Write-Error "Unable to access Get-CimInstance Win32_BIOS on $Computer & therefor unable to pull ServiceTag data."
            }


            ## AssetTag ##
            try {
                $Object.AssetTag = (Get-CimInstance Win32_SystemEnclosure -ComputerName $Computer -ErrorAction Stop).SMBiosAssetTag.split(' ')[0].ToUpper()
                Write-Debug "SMBiosAssetTag Results: $($Object.AssetTag)"
            }
            catch {
                Write-Error "Unable to access Get-CimInstance Win32_SystemEnclosure on $Computer & therefor unable to pull AssetTag data."
            }


            ## InstallDate ##
            try {
                $Object.InstallDate = "Deployed " + (
                    Get-CimInstance Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop
                ).InstallDate.ToString("yyyy-MM-dd")
                Write-Debug "InstallDate Results: $($Object.InstallDate)"
            }
            catch {
                Write-Error "Unable to access Get-CimInstance Win32_OperatingSystem"
            }

            Write-Output $Object
        }
    }
}
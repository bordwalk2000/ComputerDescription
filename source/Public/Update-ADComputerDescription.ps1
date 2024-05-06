﻿[CmdletBinding()]

param(
    [Parameter(Mandatory=$True)][string[]] $OUSearchLocation
)

BEGIN {
    $ComputerObjects=@()
}
PROCESS {
    $OUSearchLocation | ForEach-Object {
        Get-ADComputer -filter {Enabled -eq "True"} -Properties Description -searchbase $_ | ForEach-Object {
            $object = New-Object PSObject -Property @{
                Name = $_.Name
                PrimaryUser = ''
                ServiceTag = ''
                AssetTag = ''
                InstallDate = ''
                Description = $_.Description
            }

            if ($_.Description) {
                $DescriptionSplit = $_.Description.Split('|').trim()
                $PrimaryUser = if ($DescriptionSplit.count -gt 1){ $DescriptionSplit[0] } Else { $DescriptionSplit }

                if ($PrimaryUser -notmatch "[0-9]" -or $PrimaryUser -cnotmatch “[^A-Z]”) {
                    $object.PrimaryUser = $PrimaryUser
                }

                $DescriptionSplit | Where-Object { $_ -ne $DescriptionSplit[0] } | ForEach-Object {
                    if (![string]::IsNullOrEmpty($_)){

                        if (!$object.AssetTag -and $_.Substring(1) -cmatch “[^A-Z]” -and $_ -match "[0-9]" -and $_.Length -eq 7) {
                            $object.ServiceTag = $_

                        } elseif ($_ -clike "C00*" -and $_ -match "[0-9]" -and ($_.Length -eq 6 -or $_.Length -eq 28)) {
                            $object.AssetTag = $_

                        } elseif (@("Deployed","Reinstalled") -contains $_.Split(' ')[0]) {
                            if ($_.Split(' ').count -eq 2) {
                                if ([boolean][DateTime]::Parse($_.Split(' ')[-1])) {
                                    $object.InstallDate = $_
                                }
                            }
                        }
                    }
                }
            }
            $ComputerObjects += $object
        }
    }

    $ComputerObjects | ForEach-Object {
        if (Test-Connection $_.Name -Count 2 –Quiet) {
            Write-Verbose "$($_.Name) is Online, Pulling Information."
            Write-Verbose "Existing Data: $_"
            try {
                $PrimaryUserName = (Get-WinEvent -ComputerName $_.Name -MaxEvents 300 -ErrorAction Stop -FilterHashtable @{
                    LogName ='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational';ID=21
                } |
                Where-Object {$_.Properties[0].value -notlike "*admin*" -and $_.Properties[0].value -notlike "*setup*"} |
                Select-Object -First 15 |
                Group-Object {$_.Properties[0].value} |
                Select-Object Count, Name, @{ Name = 'Latest'; Expression = { ($_.Group | Measure-Object -Property TimeCreated -Maximum).Maximum } } |
                Sort-Object Count, Latest -Descending |
                Select-Object Name -first 1)

                Write-Debug "PrimaryUserName Results: $PrimaryUserName"

                if ($PrimaryUserName) {
                    try {
                        # Check to see if username is in Active Directory
                        $_.PrimaryUser = (Get-ADuser $PrimaryUserName.name.split('\')[-1]).Name
                    }
                    catch {
                        $Error.add("An error occurred finding AD User $($PrimaryUserName.name.split('\')[-1]).") | Out-Null
                    }
                    # If Get-ADUser Encoroed an Error, Assign the Unprocessed PrimaryUser To PrimaryUser Instead
                    if ($Error[-1] -eq "An error occurred finding AD User $($PrimaryUserName.name.split('\')[-1])."){
                        $_.PrimaryUser = $PrimaryUserName.Name
                    }
                }
                Write-Debug $_.PrimaryUser
            } catch {
                Write-Verbose "Unable to access Get-WinEvent"
            }

            try {
                $ServiceTag = (Get-CimInstance Win32_BIOS -Computername $_.Name -ErrorAction Stop).SerialNumber
                Write-Debug "SerialNumber Results: $ServiceTag"
                if ($ServiceTag) {
                    if ($ServiceTag -match "vmware") {
                        $_.ServiceTag = 'VMWare VM'
                    } else {
                        $_.ServiceTag = $ServiceTag
                    }
                }
            } catch {
                Write-Verbose "Unable to access Get-CimInstance Win32_BIOS"
            }

            try {
                $AssetTag = (Get-CimInstance Win32_SystemEnclosure -Computername $_.Name -ErrorAction Stop).SMBiosAssetTag.split(' ')[0]
                Write-Debug "SMBiosAssetTag Results: $AssetTag"
                if ($AssetTag) {
                    $_.AssetTag = $AssetTag.ToUpper()
                } elseif ($_.AssetTag -and $_.AssetTag.Length -eq 6) {
                    $_.AssetTag = $_.AssetTag + " ***MISSING IN BIOS***"
                }
            } catch {
                Write-Verbose "Unable to access Get-CimInstance Win32_SystemEnclosure"
            }

            if (!$_.InstallDate) {
                try {
                    $_.InstallDate = "Deployed " + (
                        Get-CimInstance Win32_OperatingSystem -ComputerName $_.Name -ErrorAction Stop
                    ).InstallDate.ToString("yyyy-MM-dd")
                    Write-Debug "InstallDate Results: $($_.InstallDate)"
                } catch {
                    Write-Verbose "Unable to access Get-CimInstance Win32_OperatingSystem"
                }
            }

            # Print Variable Information
            Write-Debug "Processed Results: $_"

            # Remove any left over $GeneratedDescription variable data
            Remove-Variable GeneratedDescription -ErrorAction Ignore

            # Verifiy Data was Retrieved Before Updating Results
            if ([string]::IsNullOrEmpty($_.ServiceTag) -or [string]::IsNullOrEmpty($_.InstallDate)) {
                Write-Verbose "$($_.Name) is online but was unable to build the description."
            } else {
                $GeneratedDescription = [String]::Join(" | ", @($_.Primaryuser, $_.ServiceTag, $_.AssetTag.trim(), $_.InstallDate))
            }

            if ($_.Description -ne $GeneratedDescription)
            {
                Write-Verbose "Updating $($_.Name) Description from '$($_.Description)' to '$GeneratedDescription'"
                Set-ADComputer -Identity $_.Name -Description $GeneratedDescription
            }
        } else {
            Write-Verbose "$($_.Name) is Offline."
        }
    }
}
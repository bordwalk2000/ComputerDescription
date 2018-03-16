$OUSearchLocation = "OU=Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com" , "OU=No_Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com"
$ComputerObjects=@()

$OUSearchLocation | % {
    Get-ADComputer -filter {Enabled -eq "True"} -Properties Description -searchbase $_ | % {
        $object = New-Object PSObject -Property @{
            Name = $_.Name
            PrimaryUser = ''
            ServiceTag = ''
            AssetTag = ''
            InstallDate = ''
            Description = $_.Description
        }
        
        if($_.Description) {
            $DescriptionSplit = $_.Description.Split('|').trim()
            $PrimaryUser = if($DescriptionSplit.count -gt 1){ $DescriptionSplit[0] } Else{ $DescriptionSplit}

            if($PrimaryUser -notmatch "[0-9]" -or $PrimaryUser -cnotmatch “[^A-Z]”) {
                $object.PrimaryUser = $PrimaryUser
            }

            $DescriptionSplit | Where-Object { $_ -ne $DescriptionSplit[0] } | % {
                if(![string]::IsNullOrEmpty($_)){

                    if(!$object.AssetTag -and $_.Substring(1) -cmatch “[^A-Z]” -and $_ -match "[0-9]" -and $_.Length -eq 7) {
                        $object.ServiceTag = $_
                    }

                    if($_ -clike "C00*" -and $_ -match "[0-9]" -and ($_.Length -eq 6 -or $_.Length -eq 28)) {
                        $object.AssetTag = $_
                    }

                    if(@("Deployed","Reinstalled") -contains $_.Split(' ')[0]) {
                        if($_.Split(' ').count -eq 2) {
                            if([boolean][DateTime]::Parse($_.Split(' ')[-1])) {
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

$ComputerObjects | % {
    if(Test-Connection $_.Name -Count 2 -ea SilentlyContinue) {

        if($_.Name -notlike "MO-STL-MIS*") {
            $PrimaryUserName = (Get-WinEvent -ComputerName $_.Name -MaxEvents 300 -ErrorAction SilentlyContinue -FilterHashtable @{LogName ='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational';ID=21} |  
            ? {$_.Properties[2].value -eq "local" -and  $_.Properties[0].value -notlike "*admin*" -and  $_.Properties[0].value -notlike "*setup*"} | 
            Select -First 7 | 
            Group-Object {$_.Properties[0].value} |
            Select count,name,@{ Name = 'Latest'; Expression = { ($_.Group | Measure-Object -Property TimeCreated -Maximum).Maximum } } |
            Sort Count ,Latest -Descending |
            Select Name -first 1)
        
            if($PrimaryUserName) { 
                $_.PrimaryUser = (Get-ADuser $PrimaryUserName.name.split('\')[-1]).Name
                Remove-Variable PrimaryUserName -ErrorAction SilentlyContinue
            }
        }

        $ServiceTag = (Get-WmiObject Win32_BIOS -Computername $_.Name).SerialNumber
        if($ServiceTag) {
            $_.ServiceTag = $ServiceTag
        }

        $AssetTag = (Get-WmiObject Win32_SystemEnclosure -Computername $_.Name).SMBiosAssetTag
        if($AssetTag) {
            $_.AssetTag = $AssetTag.ToUpper()
        } elseif ($_.AssetTag -and $_.AssetTag.Length -eq 6) {
            $_.AssetTag = $_.AssetTag + " ***MISSING IN BIOS***"
        }

        if(!$_.InstallDate) {
            $_.InstallDate = "Deployed " + ([WMI]"").ConvertToDateTime((Get-WmiObject Win32_OperatingSystem -ComputerName mo-stl-mfg-dt06).InstallDate).ToString("yyyy-MM-dd")
        }

        $GeneratedDescription = [String]::Join(" | ", @($_.Primaryuser, $_.ServiceTag, $_.AssetTag.trim(), $_.InstallDate))

        if($_.Description -ne $GeneratedDescription)
        {
            Set-ADComputer -Identity $_.Name -Description $GeneratedDescription
        }
    }
}

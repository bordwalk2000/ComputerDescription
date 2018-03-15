$OUSearchLocation = "OU=Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com" , "OU=No_Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com"
$ComputerObjects=@()

$OUSearchLocation | % {

    Get-ADComputer -filter {Enabled -eq "True"} -Properties Description -searchbase $_ | 
    % {
        $object = New-Object PSObject -Property @{
            Name = $_.Name
            PrimaryUser = ''
            ServiceTag = ''
            AssetTag = ''
            InstallDate = ''
        }
        
        if($_.Description) {
            $DescriptionSplit = $_.Description.Split('|').trim()

            $PrimaryUser = if($DescriptionSplit.count -gt 1){ $DescriptionSplit[0] } Else{ $DescriptionSplit}
            if($PrimaryUser -notmatch "[0-9]" -or $PrimaryUser -cnotmatch “[^A-Z]”) {
                $object.PrimaryUser = $PrimaryUser
            }

            if($DescriptionSplit.count -gt 2) {

                if(![string]::IsNullOrEmpty($DescriptionSplit[1])){
                    if($DescriptionSplit[1] -match "[0-9]" -and $DescriptionSplit[1] -cmatch “[^A-Z]” -or $DescriptionSplit[1] -cnotlike "C00*") {
                        $object.ServiceTag = $DescriptionSplit[1]
                    }
                }
                

                if(![string]::IsNullOrEmpty($DescriptionSplit[2])){
                    if($DescriptionSplit[2] -clike "C00*" -and $DescriptionSplit[2] -match "[0-9]" -and $DescriptionSplit[2].Length -eq 6) {
                        $object.AssetTag = $DescriptionSplit[2]
                    }
                }

                if(![string]::IsNullOrEmpty($DescriptionSplit[3])){
                    if($DescriptionSplit[3].Split(' ').count -eq 2) {
                    
                        if (@("Deployed","Reinstalled") -contains $DescriptionSplit[3].Split(' ')[0] -and [boolean][DateTime]::Parse($DescriptionSplit[3].Split(' ')[-1])){
                            $object.InstallDate = $DescriptionSplit[3]
                        }
                    }
                }
            }
        }
        $ComputerObjects += $object
    }
}
$ComputerObjects | Sort Name | ft Name, PrimaryUser, ServiceTag, AssetTag, InstallDate

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


            $DescriptionSplit | Where-Object { $_ -ne $array[0] } | % {

                if(![string]::IsNullOrEmpty($_)){

                    if(!$object.AssetTag -and $_.Substring(1) -cmatch “[^A-Z]” -and $_ -match "[0-9]" -and $_.Length -eq 7) {
                        $object.ServiceTag = $_
                    }

                    if($_ -clike "C00*" -and $_ -match "[0-9]" -and $_.Length -eq 6) {
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
$ComputerObjects | Sort Name | ft Name, PrimaryUser, ServiceTag, AssetTag, InstallDate

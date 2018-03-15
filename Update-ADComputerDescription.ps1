$OUSearchLocation = "OU=Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com", "OU=No_Reboot,OU=Computers,OU=mo-stl-obrien,DC=ametek,DC=com"

$OUSearchLocation | % {

    Get-ADComputer -filter {Enabled -eq "True"} -Properties Description -searchbase $_  | #Select -first 1 | 
    % {
        if($_.Description) {
            $DescriptionSplit = $_.Description.Split('|').trim()

            if($DescriptionSplit.count -gt 1) {

                if($DescriptionSplit[0] -match "[0-9]" -or $DescriptionSplit[0] -cmatch “^[A-Z]*$”) {
                    $_.Name + " Name: " + $DescriptionSplit[0]
                    
                }

                if(![string]::IsNullOrEmpty($DescriptionSplit[1])){
                    if($DescriptionSplit[1] -notmatch "[0-9]" -and $DescriptionSplit[1] -cnotmatch “^[A-Z]*$” -or $DescriptionSplit[1] -clike "C00*") {
                        $_.Name + " Dell Service Tag: " + $DescriptionSplit[1]
                    }
                }

                if(![string]::IsNullOrEmpty($DescriptionSplit[2])){
                    if($DescriptionSplit[2] -cnotlike "C00*" -and $DescriptionSplit[2] -notmatch "[0-9]" ) {
                        $_.Name + " Serial Number: " + $DescriptionSplit[2]
                    }
                }

                if(![string]::IsNullOrEmpty($DescriptionSplit[3])){
                    if($DescriptionSplit[3].Split(' ').count -ne 2) {
                        $_.Name + " Install Date: " + $DescriptionSplit[3]
                    } elseif (@("Deployed","Reinstalled") -notcontains $DescriptionSplit[3].Split(' ')[0] -and ![boolean][DateTime]::Parse($DescriptionSplit[3].Split(' ')[-1])){
                        $_.Name + " Install Date: " + $DescriptionSplit[3].Split(' ')
                    }
                }
            }
        }
        
        #if(Test-Connection $_.Name -Count 1 -ea SilentlyContinue) {  }
    }
}
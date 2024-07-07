# ComputerDescription PowerShell Module

This module retrieves information from Windows computers, creates a description string, and compares it to the existing description in Active Directory. If there are discrepancies, the script will prompt you to confirm any changes before updating the Active Directory object description field.

The AD Computer description will be stored in the following format.

```text
Primary User | Service Tag [| Asset Tag] | 'Deployed' OS Installed Date (YYYY-MM-DD)
```

## 🚀 Getting Started

The following is the bare minimum required to successfully run the Update-ADComputerDescription function and update an AD object's description.

```powershell
Update-ADComputerDescription -ComputerName PC1
```

Example AD computer description from the previous command

```text
John Smith | ABCD123 | Deployed 2024-12-31
```

To store AssetTag information and avoid being prompted to confirm changes, run the following command.

```powershell
Update-ADComputerDescription -OUPath 'OU=Computers,DC=Example,DC=com' -AssetTagSupport -AssetTagRegex '^[C]\d{5}$' -Confirm:$false 
```

Example AD computer description from the previous command

```text
John Smith | ABCD123 | C12345 | Deployed 2024-12-31
```


I suggest starting by targeting a few machines or an Organizational Unit (OU) with a limited number of computer objects. This approach allows you to verify that everything is working correctly. If you encounter any issues, you can use the following switches to gather more detailed information about the process.

```powershell
Update-ADComputerDescription -ComputerName PC1, PC2, PC3 -Verbose -Debug
```

## ❗ Warning
After you confirm that you want to update the AD computer's description this will overwrite what was previously stored there and you can no longer get it back.  I highly recommend creating a backup of of your AD computer's description field before running the script.

```powershell
Get-ADComputer -Filter * -Properties Description -SearchBase "OU=Computers,DC=Example,DC=com" | Select Name, Description | Export-Csv "AD Computer Descriptions.csv" 
```

## 💿 Installation

This module is hosted on the PowerShell gallery.  It can be installed using the following command.

```powershell
Install-Module -Name ComputerDescription
```

## 💽 Building Module from Scratch

This module is currently being built with the gaelcolas's [Sampler](https://github.com/gaelcolas/Sampler) module using the build.ps1 file.

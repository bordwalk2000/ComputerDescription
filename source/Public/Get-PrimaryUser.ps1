<#
.SYNOPSIS
    Retrieves the primary user of a specified computer.

.DESCRIPTION
    The Get-PrimaryUser function connects to a specified computer and retrieves the primary user by
    analyzing recent Terminal Services local session manager events.
    It filters out administrative and setup accounts and identifies the user with the most session logins.

.PARAMETER ComputerName
    The name of the computer to query for the primary user.
    This parameter is mandatory and accepts values from the pipeline.

.EXAMPLE
    PS C:\> "Computer1" | Get-PrimaryUser

    Retrieves the primary user of "Computer1".

.EXAMPLE
    PS C:\> Get-PrimaryUser -ComputerName "Computer1"

    Retrieves the primary user of "Computer1".

.NOTES
    - This function requires the ability to read Windows event logs on the specified computer.
    - Ensure you have the necessary permissions to access event logs on the target computer.

#>
Function Get-PrimaryUser {
    param(
        # List of Computer Name
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0
        )]
        [string]
        $ComputerName
    )

    # Get Windows events log list from computer
    (
        Get-WinEvent -ComputerName $ComputerName -MaxEvents 300 -ErrorAction Stop -FilterHashtable @{
            LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; ID = 21
        }
        | Where-Object {
            $_.Properties[0].value -notlike "*admin*" -and
            $_.Properties[0].value -notlike "*setup*"
        }
        | Select-Object -First 15
        | Group-Object { $_.Properties[0].value }
        | Select-Object Count, Name, @{
            Name = 'Latest'; Expression = {
                ($_.Group | Measure-Object -Property TimeCreated -Maximum).Maximum
            }
        }
        | Sort-Object Count, Latest -Descending
        | Select-Object -ExpandProperty Name -First 1
    )
}
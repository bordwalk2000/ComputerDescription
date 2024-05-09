Function Get-PrimaryUser {
    [CmdletBinding()]
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
        } |
            Where-Object {
                $_.Properties[0].value -notlike "*admin*" -and
                $_.Properties[0].value -notlike "*setup*"
            } |
                Select-Object -First 15 |
                    Group-Object { $_.Properties[0].value } |
                        Select-Object Count, Name, @{
                            Name = 'Latest'; Expression = {
                            ($_.Group | Measure-Object -Property TimeCreated -Maximum).Maximum
                            }
                        } |
                            Sort-Object Count, Latest -Descending |
                                Select-Object -ExpandProperty Name -First 1
    )
}
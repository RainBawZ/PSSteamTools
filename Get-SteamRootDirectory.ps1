Function Get-SteamRootDirectory {
    [CmdletBinding()]
    [OutputType([IO.DirectoryInfo])]
    Param ()

    [String]$RegKey              = 'HKLM:\SOFTWARE' + ('\', '\WOW6432Node\')[[Environment]::Is64BitOperatingSystem] + 'Valve\Steam'
    [IO.DirectoryInfo]$SteamRoot = Get-ItemPropertyValue $RegKey InstallPath

    If (!$SteamRoot.Exists) {Throw [IO.DirectoryNotFoundException]::New("Unable to locate Steam Root Directory in Registry Key '$RegKey'.")}

    Return $SteamRoot
}

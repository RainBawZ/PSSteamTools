Function Convert-SteamId {
    [CmdletBinding(DefaultParameterSetName = 'Auto')]
    [OutputType([String], [UInt32], [UInt64])]
    Param(
        # Accepts:
        # - SteamID64: 7656119...
        # - AccountID/SteamID32: 0..4294967295
        # - SteamID2: STEAM_0:1:12345
        # - SteamID3: [U:1:12345]
        [Parameter(Mandatory, Position = 0)]
        [Alias('SteamId','Input','Id')]
        [Object]$SteamIdInput,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('SteamID64', 'AccountID', 'SteamID32', 'SteamID3', 'SteamID2')]
        [Alias('To')]
        [String]$Type,

        # Optional hint. Auto-detect if omitted.
        [Parameter(Position = 2, ParameterSetName = 'Explicit')]
        [ValidateSet('Auto', 'SteamID64', 'AccountID', 'SteamID32', 'SteamID3', 'SteamID2')]
        [String]$From = 'Auto'
    )

    [UInt64]$SteamId64Base = 76561197960265728                   # SteamID64 base value (not an actual SteamID64)
    [String]$IdString      = ($SteamIdInput -As [String]).Trim() # Input as string

    # ====== Normalize input ID type to AccountID ======
    If ($From -eq 'Auto') {
        If ($IdString -Match '^\d+$') {
            # Numeric: Could be SteamID64 or AccountID/SteamID32
            # Heuristic: SteamID64 is >= base; AccountID fits in UInt32.
            Try   {[UInt64]$IdNumeric = $IdString}
            Catch {Throw "Numeric SteamID input '$IdString' is not a valid unsigned integer."}

            If     ($IdNumeric -ge $SteamId64Base)     {$From = 'SteamID64'}
            ElseIf ($IdNumeric -le [UInt32]::MaxValue) {$From = 'AccountID'}
            Else                                       {Throw "Numeric SteamID input '$IdString' is neither a valid SteamID64 nor a UInt32 AccountID/SteamID32."}
        }
        ElseIf ($IdString -Match '^STEAM_\d+:[01]:\d+$')            {$From = 'SteamID2'}
        ElseIf ($IdString -Match '^\[[A-Za-z]:\d+:\d+(?::\d+)?\]$') {$From = 'SteamID3'}
        Else                                                        {Throw "Unable to auto-detect SteamID format from '$IdString'."}
    }

    Switch -Regex ($From) {
        '^SteamID64$' {
            Try   {[UInt64]$Id64 = $IdString}
            Catch {Throw "SteamID64 '$IdString' is not a valid UInt64."}

            If ($Id64 -lt $SteamId64Base) {Throw "Provided SteamID64 '$Id64' is less than the minimum valid SteamID64 value."}

            [UInt64]$Acc64 = $Id64 - $SteamId64Base
            If ($Acc64 -gt [UInt32]::MaxValue) {Throw "Derived AccountID '$Acc64' exceeds UInt32 max value and cannot be a standard individual SteamID64."}

            [UInt32]$AccountId = $Acc64
            Break
        }

        '^(AccountID|SteamID32)$' {
            Try   {[UInt64]$IdNumeric = $IdString}
            Catch {Throw "AccountID/SteamID32 '$IdString' is not a valid unsigned integer."}

            If ($IdNumeric -gt [UInt32]::MaxValue) {Throw "AccountID/SteamID32 '$IdNumeric' exceeds UInt32 max value."}

            [UInt32]$AccountId = $IdNumeric
            Break
        }

        '^SteamID2$' {
            # STEAM_X:Y:Z  => AccountID = Z*2 + Y
            If ($IdString -NotMatch '^STEAM_(?<Universe>\d+):(?<Y>[01]):(?<Z>\d+)$') {Throw "SteamID2 '$IdString' is not in a recognized format (expected STEAM_X:Y:Z)."}

            [UInt32]$y = [UInt32]$Matches.Y

            # Z can be large, validate carefully
            Try   {[UInt64]$z = $Matches.Z}
            Catch {Throw "SteamID2 '$IdString' has an invalid Z component."}

            [UInt64]$Acc = ($z * 2) + $y
            If ($Acc -gt [UInt32]::MaxValue) {Throw "SteamID2 '$IdString' converts to AccountID '$Acc' which exceeds UInt32 max value."}

            [UInt32]$AccountId = $Acc
            Break
        }

        '^SteamID3$' {
            # Common individual form: [U:1:<accountid>]
            # Note: SteamID3 can represent non-user types. This accepts only "U" for now.
            If ($IdString -NotMatch '^\[(?<Type>[A-Za-z]):(?<Universe>\d+):(?<Id>\d+)(?::(?<Instance>\d+))?\]$') {Throw "SteamID3 '$IdString' is not in a recognized format."}
            
            [String]$IdType = $Matches.Type
            
            If ($IdType -ne 'U') {Throw "SteamID3 '$IdString' is type '$IdType'. This function currently supports only individual user IDs (type 'U')."}

            Try   {[UInt64]$Id = $Matches.Id }
            Catch {Throw "SteamID3 '$IdString' has an invalid account/id component."}

            If ($Id -gt [UInt32]::MaxValue) {Throw "SteamID3 '$IdString' converts to AccountID '$Id' which exceeds UInt32 max value."}

            [UInt32]$AccountId = $Id
            Break
        }

        Default {Throw "Unknown input SteamID type '$From'."}
    }
    # =======

    # Derive other SteamID representations from AccountID
    [UInt64]$SteamId64 = $SteamId64Base + $AccountId
    [Byte]$Y           = $AccountId % 2
    [UInt32]$Z         = ($AccountId - $Y) / 2

    Switch ($Type) {
        'SteamID64' {Return $SteamId64 }
        'AccountID' {Return $AccountId }
        'SteamID32' {Return $AccountId }                 # SteamID32 == AccountID
        'SteamID3'  {Return "[U:1:$AccountId]" }         # Individual user
        'SteamID2'  {Return "STEAM_0:$($Y):$Z" }         # Universe 0
        Default     {Throw "Unknown output SteamID type '$Type'." }
    }
}

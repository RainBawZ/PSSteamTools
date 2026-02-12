Function Import-Vdf {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ $_.Exists })]
        [IO.FileInfo]$Path
    )

    [String]$RawVdf = Get-FileContent -Path $Path -Raw

    # Tokenize: Quoted strings OR braces
    # This ignores whitespace and newlines entirely.
    [Text.RegularExpressions.MatchCollection]$TokenMatches = [Regex]::Matches($RawVdf, '"([^"\\]*(?:\\.[^"\\]*)*)"|\{|\}')

    [PSCustomObject]$Root = [PSCustomObject]@{}

    [System.Collections.Generic.Stack[PSCustomObject]]$ObjectStack = [System.Collections.Generic.Stack[PSCustomObject]]::New()
    [System.Collections.Generic.Stack[String]]$KeyStack            = [System.Collections.Generic.Stack[String]]::New()

    [PSCustomObject]$Current = $Root
    [String]$PendingString   = $Null

    ForEach ($Match in $TokenMatches) {

        [String]$Token = $Match.Value

        If ($Token -eq '{') {
            # Start a new object scope.
            $ObjectStack.Push($Current)

            [PSCustomObject]$NewObj = [PSCustomObject]@{}

            If (![String]::IsNullOrEmpty($PendingString)) {
                # Named object: Remember key to attach on close
                $KeyStack.Push($PendingString)
                $PendingString = $Null
            }
            Else {
                # Anonymous scope (no key). Mark with a null sentinel.
                $KeyStack.Push($Null)
            }

            $Current = $NewObj
            Continue
        }

        If ($Token -eq '}') {
            If ($ObjectStack.Count -lt 1 -Or $KeyStack.Count -lt 1) {Throw "VDF Parse Error: Encountered '}' with an empty stack (Objects=$($ObjectStack.Count), Keys=$($KeyStack.Count))."}

            [PSCustomObject]$Parent = $ObjectStack.Pop()
            [String]$Key            = $KeyStack.Pop()

            If (![String]::IsNullOrEmpty($Key) -And $Key.Length -gt 0) {
                # Attach closed object to parent
                $Parent | Add-Member -MemberType NoteProperty -Name $Key -Value $Current -Force
            }
            Else {
                # Anonymous block - Nothing to attach by name.
                # Store in a list property instead of if they're needed at all.
            }

            $Current       = $Parent
            $PendingString = $Null
            Continue
        }

        # It's a quoted string; extract content (group 1) and unescape \" and \\ minimally
        [String]$String = $Match.Groups[1].Value -Replace '\\\\', '\' -Replace '\\"', '"'

        If ([String]::IsNullOrEmpty($PendingString)) {$PendingString = $String}
        Else {
            # We have key/value
            $Current | Add-Member -MemberType NoteProperty -Name $PendingString -Value $String -Force
            $PendingString = $Null
        }
    }

    If ($ObjectStack.Count -ne 0 -Or $KeyStack.Count -ne 0) {Throw "VDF Parse Error: Unbalanced braces (Objects=$($ObjectStack.Count), Keys=$($KeyStack.Count))."}

    Return $Root
}

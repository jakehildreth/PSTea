function ConvertFrom-ElmKeyString {
    <#
    .SYNOPSIS
        Parses a canonical key string into a ConsoleKey and ConsoleModifiers value.

    .DESCRIPTION
        Converts human-readable key strings like 'Q', 'Ctrl+Q', 'UpArrow',
        'Ctrl+Shift+Home' into a PSCustomObject containing the equivalent
        System.ConsoleKey enum value and System.ConsoleModifiers flags.

        Modifier prefixes (case-insensitive):
          Ctrl, Control, Alt, Shift

        Common key aliases (case-insensitive):
          Esc      -> Escape
          Return   -> Enter
          Space    -> Spacebar
          Del      -> Delete
          Ins      -> Insert
          Up       -> UpArrow
          Down     -> DownArrow
          Left     -> LeftArrow
          Right    -> RightArrow
          PgUp     -> PageUp
          PgDn     -> PageDown
          0-9      -> D0-D9  (top-row digit keys)

    .PARAMETER KeyString
        The key string to parse. Format: [Modifier+]Key
        Examples: 'Q', 'Ctrl+Q', 'Alt+F4', 'Ctrl+Shift+Home', 'UpArrow', 'F1'

    .OUTPUTS
        PSCustomObject with Key ([System.ConsoleKey]) and Modifiers ([System.ConsoleModifiers]).

    .EXAMPLE
        ConvertFrom-ElmKeyString -KeyString 'Q'
        # Key = [ConsoleKey]::Q, Modifiers = 0

    .EXAMPLE
        ConvertFrom-ElmKeyString -KeyString 'Ctrl+Shift+N'
        # Key = [ConsoleKey]::N, Modifiers = Control | Shift

    .NOTES
        Used internally by New-ElmKeySub to build typed subscription objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyString
    )
    process {
        $parts   = $KeyString.Trim() -split '\+'
        $keyName = $parts[-1].Trim()

        [int]$modFlags = 0

        if ($parts.Length -gt 1) {
            foreach ($part in $parts[0..($parts.Length - 2)]) {
                switch ($part.Trim().ToLower()) {
                    'ctrl'    { $modFlags = $modFlags -bor [int][System.ConsoleModifiers]::Control }
                    'control' { $modFlags = $modFlags -bor [int][System.ConsoleModifiers]::Control }
                    'alt'     { $modFlags = $modFlags -bor [int][System.ConsoleModifiers]::Alt }
                    'shift'   { $modFlags = $modFlags -bor [int][System.ConsoleModifiers]::Shift }
                    default {
                        $ex  = [System.ArgumentException]::new(
                            "Unknown modifier: '$($part.Trim())'. Valid modifiers: Ctrl, Alt, Shift."
                        )
                        $err = [System.Management.Automation.ErrorRecord]::new(
                            $ex, 'UnknownModifier',
                            [System.Management.Automation.ErrorCategory]::InvalidArgument,
                            $KeyString
                        )
                        $PSCmdlet.ThrowTerminatingError($err)
                    }
                }
            }
        }

        # Normalize common aliases to ConsoleKey enum names
        $normalised = switch ($keyName.ToLower()) {
            'esc'     { 'Escape' }
            'return'  { 'Enter' }
            'space'   { 'Spacebar' }
            'del'     { 'Delete' }
            'ins'     { 'Insert' }
            'up'      { 'UpArrow' }
            'down'    { 'DownArrow' }
            'left'    { 'LeftArrow' }
            'right'   { 'RightArrow' }
            'pgup'    { 'PageUp' }
            'pgdn'    { 'PageDown' }
            '0'       { 'D0' }
            '1'       { 'D1' }
            '2'       { 'D2' }
            '3'       { 'D3' }
            '4'       { 'D4' }
            '5'       { 'D5' }
            '6'       { 'D6' }
            '7'       { 'D7' }
            '8'       { 'D8' }
            '9'       { 'D9' }
            default   { $keyName }
        }

        # Try enum parse (case-insensitive via PowerShell cast)
        $consoleKey = $null
        try {
            $consoleKey = [System.ConsoleKey]$normalised
        } catch {
            $ex  = [System.ArgumentException]::new(
                "Unknown key: '$keyName'. Must be a valid System.ConsoleKey name (e.g. 'Q', 'Enter', 'UpArrow', 'F1')."
            )
            $err = [System.Management.Automation.ErrorRecord]::new(
                $ex, 'UnknownKey',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $KeyString
            )
            $PSCmdlet.ThrowTerminatingError($err)
        }

        return [PSCustomObject]@{
            Key       = $consoleKey
            Modifiers = [System.ConsoleModifiers]$modFlags
        }
    }
}

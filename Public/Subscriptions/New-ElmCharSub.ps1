function New-ElmCharSub {
    <#
    .SYNOPSIS
        Creates a printable-character subscription for use in a SubscriptionFn.

    .DESCRIPTION
        Returns a subscription descriptor that fires for any printable character
        (Unicode code point 0x0020-0x007E) that was NOT already consumed by a
        specific New-ElmKeySub in the same subscription list.

        The handler scriptblock receives the raw KeyDown event as its first
        argument. The event object has a 'Char' property containing the typed
        System.Char. The handler must return a message object (or $null to
        suppress the message).

    .PARAMETER Handler
        Scriptblock invoked for each unmatched printable character. Receives the
        KeyDown event as the first argument.

        Example: { param($e) "Input:$([string]$e.Char)" }

    .OUTPUTS
        PSCustomObject with Type='Char' and Handler properties.

    .EXAMPLE
        New-ElmCharSub -Handler { param($e) "Input:$([string]$e.Char)" }

    .NOTES
        Add alongside specific New-ElmKeySub entries. Key subs take priority: if
        a key sub matches (e.g. Q → Quit), the char sub does NOT fire for that key.
        Use New-ElmKeySub for control keys (arrows, Enter, Backspace) and
        New-ElmCharSub for free-text input.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    return [PSCustomObject]@{
        Type    = 'Char'
        Handler = $Handler
    }
}

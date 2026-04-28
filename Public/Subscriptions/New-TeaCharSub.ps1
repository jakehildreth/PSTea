function New-TeaCharSub {
    <#
    .SYNOPSIS
        Creates a printable-character subscription for use in a SubscriptionFn.

    .DESCRIPTION
        Returns a subscription descriptor that fires for any printable character
        (Unicode code point 0x0020-0x007E) that was NOT already consumed by a
        specific New-TeaKeySub in the same subscription list.

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
        New-TeaCharSub -Handler { param($e) "Input:$([string]$e.Char)" }

    .NOTES
        Add alongside specific New-TeaKeySub entries. Key subs take priority: if
        a key sub matches (e.g. Q → Quit), the char sub does NOT fire for that key.
        Use New-TeaKeySub for control keys (arrows, Enter, Backspace) and
        New-TeaCharSub for free-text input.
    #>
    [OutputType([PSCustomObject])]
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

Set-Alias -Name TeaCharSub           -Value New-TeaCharSub

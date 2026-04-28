function New-TeaKeySub {
    <#
    .SYNOPSIS
        Creates a keyboard subscription for use in a SubscriptionFn.

    .DESCRIPTION
        Returns a subscription descriptor that matches a specific key (with optional
        modifier) from the terminal input queue and invokes a handler scriptblock when
        the key is pressed, producing a message for the Update function.

        The handler scriptblock receives the raw KeyDown event as its first argument
        and must return a message object (or $null to suppress the message).

        Letter keys (A-Z) are matched case-insensitively: a subscription for 'Q' will
        fire for both lowercase 'q' and uppercase 'Q' (Shift+Q), unless you explicitly
        include 'Shift' in the key string.

    .PARAMETER Key
        Canonical key string. Format: [Modifier+]KeyName.
        Examples: 'Q', 'Ctrl+Q', 'UpArrow', 'F1', 'Ctrl+Shift+Home', 'Space', 'Enter'
        See ConvertFrom-TeaKeyString for the full alias list.

    .PARAMETER Handler
        Scriptblock invoked when the key fires. Receives the KeyDown event as first
        argument. Must return a message object or $null.

        Example: { 'Quit' }
        Example: { param($e) [PSCustomObject]@{ Type = 'KeyPressed'; Key = $e.Key } }

    .OUTPUTS
        PSCustomObject with Type='Key', ConsoleKey, Modifiers, and Handler properties.

    .EXAMPLE
        New-TeaKeySub -Key 'Q' -Handler { 'Quit' }

    .EXAMPLE
        New-TeaKeySub -Key 'UpArrow' -Handler { 'MoveUp' }

    .EXAMPLE
        New-TeaKeySub -Key 'Ctrl+C' -Handler { [PSCustomObject]@{ Type='Quit' } }

    .NOTES
        Use inside a SubscriptionFn passed to Start-TeaProgram via -SubscriptionFn.
        Subscriptions are re-evaluated on every model change, enabling conditional
        subscriptions based on model state.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    $parsed = ConvertFrom-TeaKeyString -KeyString $Key

    return [PSCustomObject]@{
        Type       = 'Key'
        ConsoleKey = $parsed.Key
        Modifiers  = $parsed.Modifiers
        Handler    = $Handler
    }
}

Set-Alias -Name TeaKeySub            -Value New-TeaKeySub

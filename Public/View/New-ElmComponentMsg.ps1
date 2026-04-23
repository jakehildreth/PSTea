function New-ElmComponentMsg {
    <#
    .SYNOPSIS
        Creates a ComponentMsg wrapper for routing messages to a specific component.

    .DESCRIPTION
        Wraps an inner message with a ComponentId so the parent Update function can
        dispatch it to the correct component's Update scriptblock. The pattern mirrors
        Elm's Cmd.map and Html.map approach for nested programs.

    .PARAMETER ComponentId
        The identifier of the target component. Must match the ComponentId used in
        the corresponding New-ElmComponent call.

    .PARAMETER Msg
        The inner message to forward to the component's Update scriptblock. May be
        any type: string, PSCustomObject, or other.

    .OUTPUTS
        PSCustomObject with Type='ComponentMsg', ComponentId, and Msg.

    .EXAMPLE
        # In a keyboard handler, forward a key to the search component:
        $msg = New-ElmComponentMsg -ComponentId 'search' -Msg ([PSCustomObject]@{
            Type = 'CharInput'
            Char = $key.KeyChar
        })

    .NOTES
        The parent Update scriptblock should switch on Msg.Type -eq 'ComponentMsg'
        and then route to the appropriate component by Msg.ComponentId.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComponentId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Msg
    )

    return [PSCustomObject]@{
        Type        = 'ComponentMsg'
        ComponentId = $ComponentId
        Msg         = $Msg
    }
}

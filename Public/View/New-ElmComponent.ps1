function New-ElmComponent {
    <#
    .SYNOPSIS
        Creates a Component view node for embedding a sub-program in the view tree.

    .DESCRIPTION
        A Component node represents a nested TEA (The Elm Architecture) sub-program.
        It encapsulates its own SubModel and ViewFn. Measure-ElmViewTree automatically
        expands Component nodes by calling ViewFn with SubModel and measuring the
        resulting subtree - ConvertTo-AnsiOutput and Compare-ElmViewTree never see
        raw Component nodes.

        Messages for components are routed using New-ElmComponentMsg, which wraps
        an inner message with a ComponentId so the parent Update function can
        dispatch it to the correct component's Update scriptblock.

    .PARAMETER ComponentId
        A unique string identifier for this component instance. Used by
        New-ElmComponentMsg to route messages to the correct component.

    .PARAMETER SubModel
        The component's own model object (PSCustomObject). Passed as the first
        argument to ViewFn when the view tree is measured.

    .PARAMETER ViewFn
        Scriptblock with signature: param($SubModel) -> ViewNode
        Must return a valid view tree node (Text, Box, Row, or another Component).

    .OUTPUTS
        PSCustomObject with Type='Component', ComponentId, SubModel, and ViewFn.

    .EXAMPLE
        $counterView = { param($m) New-ElmText -Content "Count: $($m.Count)" }
        $counter = New-ElmComponent -ComponentId 'counter' `
                                    -SubModel ([PSCustomObject]@{ Count = 0 }) `
                                    -ViewFn $counterView

    .NOTES
        Component nodes are transparent after layout - all measured nodes in the
        output tree will be Text or Box types only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComponentId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$SubModel,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$ViewFn
    )

    return [PSCustomObject]@{
        Type        = 'Component'
        ComponentId = $ComponentId
        SubModel    = $SubModel
        ViewFn      = $ViewFn
    }
}

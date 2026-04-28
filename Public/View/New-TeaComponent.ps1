function New-TeaComponent {
    <#
    .SYNOPSIS
        Creates a Component view node for embedding a sub-program in the view tree.

    .DESCRIPTION
        A Component node represents a nested TEA (The Elm Architecture) sub-program.
        It encapsulates its own SubModel and ViewFn. Measure-TeaViewTree automatically
        expands Component nodes by calling ViewFn with SubModel and measuring the
        resulting subtree - ConvertTo-AnsiOutput and Compare-TeaViewTree never see
        raw Component nodes.

        Messages for components are routed using New-TeaComponentMsg, which wraps
        an inner message with a ComponentId so the parent Update function can
        dispatch it to the correct component's Update scriptblock.

    .PARAMETER ComponentId
        A unique string identifier for this component instance. Used by
        New-TeaComponentMsg to route messages to the correct component.

    .PARAMETER SubModel
        The component's own model object (PSCustomObject). Passed as the first
        argument to ViewFn when the view tree is measured.

    .PARAMETER ViewFn
        Scriptblock with signature: param($SubModel) -> ViewNode
        Must return a valid view tree node (Text, Box, Row, or another Component).

    .OUTPUTS
        PSCustomObject with Type='Component', ComponentId, SubModel, and ViewFn.

    .EXAMPLE
        $counterView = { param($m) New-TeaText -Content "Count: $($m.Count)" }
        $params = @{
            ComponentId = 'counter'
            SubModel    = [PSCustomObject]@{ Count = 0 }
            ViewFn      = $counterView
        }
        $counter = New-TeaComponent @params

    .NOTES
        Component nodes are transparent after layout - all measured nodes in the
        output tree will be Text or Box types only.
    #>
    [OutputType([PSCustomObject])]
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

Set-Alias -Name TeaComponent         -Value New-TeaComponent

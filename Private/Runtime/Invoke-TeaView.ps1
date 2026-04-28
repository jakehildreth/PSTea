function Invoke-TeaView {
    <#
    .SYNOPSIS
        Invokes the user's View scriptblock and validates the returned node.

    .DESCRIPTION
        Calls the View scriptblock with the current model and verifies the result is a
        non-null node with a Type of 'Text' or 'Box'. Throws a terminating error if the
        View function returns null or an invalid node type.

    .PARAMETER ViewFn
        The View scriptblock: param($model) -> view tree node.

    .PARAMETER Model
        The current model to pass to the View scriptblock.

    .OUTPUTS
        PSCustomObject - the validated view tree root node.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter(Mandatory)]
        [object]$Model
    )

    $tree = & $ViewFn $Model

    if ($null -eq $tree) {
        $exception = [System.InvalidOperationException]::new('View function returned null; expected a view tree node.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'TeaViewReturnedNull',
            [System.Management.Automation.ErrorCategory]::InvalidResult,
            $ViewFn
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $validTypes = @('Text', 'Box')
    if ($null -eq $tree.Type -or $tree.Type -notin $validTypes) {
        $exception = [System.InvalidOperationException]::new(
            "View function returned a node with invalid Type '$($tree.Type)'; expected one of: $($validTypes -join ', ')."
        )
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'TeaViewInvalidNodeType',
            [System.Management.Automation.ErrorCategory]::InvalidResult,
            $tree
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $tree
}



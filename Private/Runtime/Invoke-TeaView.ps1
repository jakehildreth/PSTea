function Invoke-TeaView {
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



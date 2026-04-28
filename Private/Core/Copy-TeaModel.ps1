function Copy-TeaModel {
    <#
    .SYNOPSIS
        Returns a deep copy of a model object.

    .DESCRIPTION
        Produces a fully independent snapshot of the model by recursively deep-copying
        all PSCustomObject properties and array elements. Primitive values and strings
        are returned as-is. Used by the event loop to pass an immutable model copy to
        the Update scriptblock.

    .PARAMETER Model
        The model object to copy. Must not be $null.

    .OUTPUTS
        A deep-copied model object of the same type.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Model
    )

    if ($null -eq $Model) {
        $exception = [System.ArgumentNullException]::new(
            'Model',
            'Model cannot be null.'
        )
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'ModelIsNull',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Model
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    Copy-TeaModelValue -Value $Model
}



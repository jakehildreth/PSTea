function Copy-TeaModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Model
    )

    process {
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

        Copy-TeaModelValue $Model
    }
}



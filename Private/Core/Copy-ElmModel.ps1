function Copy-ElmModelValue {
    <#
        Private recursive helper for Copy-ElmModel.
        Walks the value graph and returns a deep clone without JSON serialization.
        Handles: $null, primitives (string/int/long/double/bool), arrays, PSCustomObject.
        Anything else (hashtable, typed .NET objects) is returned by reference - callers
        should keep typed objects out of the model (use primitives per TEA convention).
    #>
    param($Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Array]) {
        $len    = $Value.Length
        $result = [object[]]::new($len)
        for ($i = 0; $i -lt $len; $i++) {
            $result[$i] = Copy-ElmModelValue $Value[$i]
        }
        Write-Output -NoEnumerate $result
        return
    }

    if ($Value -is [PSCustomObject]) {
        $props = $Value.PSObject.Properties
        $ht    = [ordered]@{}
        foreach ($prop in $props) {
            $ht[$prop.Name] = Copy-ElmModelValue $prop.Value
        }
        return [PSCustomObject]$ht
    }

    # Primitive value types and strings - returned as-is (immutable or value-copy)
    return $Value
}

function Copy-ElmModel {
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

        Copy-ElmModelValue $Model
    }
}

function Copy-TeaModelValue {
    <#
    .SYNOPSIS
        Recursively deep-copies a model value.

    .DESCRIPTION
        Handles arrays (element-wise deep copy), PSCustomObjects (property-wise deep copy),
        and primitives/strings (returned as-is, since they are immutable or value types).
        Called by Copy-TeaModel to produce a fully independent snapshot of the model before
        passing it to the user Update function.

    .PARAMETER Value
        The value to copy. May be $null, a primitive, a string, an array, or a PSCustomObject.

    .OUTPUTS
        The deep-copied value.
    #>
    [CmdletBinding()]
    param($Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Array]) {
        $len    = $Value.Length
        $result = [object[]]::new($len)
        for ($i = 0; $i -lt $len; $i++) {
            $result[$i] = Copy-TeaModelValue $Value[$i]
        }
        Write-Output -NoEnumerate $result
        return
    }

    if ($Value -is [PSCustomObject]) {
        $props = $Value.PSObject.Properties
        $ht    = [ordered]@{}
        foreach ($prop in $props) {
            $ht[$prop.Name] = Copy-TeaModelValue $prop.Value
        }
        return [PSCustomObject]$ht
    }

    # Primitive value types and strings - returned as-is (immutable or value-copy)
    return $Value
}

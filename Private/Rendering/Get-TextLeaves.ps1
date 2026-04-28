function Get-TextLeaves {
    <#
    .SYNOPSIS
        Returns all Text leaf nodes from a measured view tree.

    .DESCRIPTION
        Performs an iterative depth-first traversal of the view tree and collects every
        node whose Type is 'Text'. Used by Compare-TeaViewTree to diff text content
        between renders.

    .PARAMETER Node
        The root node of the measured view tree.

    .OUTPUTS
        PSCustomObject[] - array of Text leaf nodes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Node
    )

    $leaves = [System.Collections.Generic.List[object]]::new()
    $stack  = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push($Node)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        if ($current.Type -eq 'Text') {
            $leaves.Add($current)
        } elseif ($current.PSObject.Properties['Children'] -and $null -ne $current.Children) {
            for ($i = $current.Children.Count - 1; $i -ge 0; $i--) {
                $stack.Push($current.Children[$i])
            }
        }
    }

    return $leaves.ToArray()
}

function Invoke-TeaDriverLoop {
    <#
    .SYNOPSIS
        Launches a driver scriptblock in a dedicated runspace.

    .DESCRIPTION
        Creates a new runspace, opens it, and begins invoking the provided scriptblock
        asynchronously. Returns a hashtable with Runspace, PowerShell, and AsyncResult so
        the caller can poll or stop the driver. Used by Start-TeaProgram and
        Start-TeaWebServer to run the input-reader and event-loop in parallel.

    .PARAMETER ScriptBlock
        The scriptblock to run in the new runspace.

    .PARAMETER Arguments
        Optional array of arguments to pass to the scriptblock.

    .OUTPUTS
        Hashtable with keys: Runspace, PowerShell, AsyncResult.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [object[]]$Arguments = @()
    )

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($ScriptBlock)

    foreach ($arg in $Arguments) {
        [void]$ps.AddArgument($arg)
    }

    $asyncResult = $ps.BeginInvoke()

    return [PSCustomObject]@{
        Runspace    = $runspace
        PowerShell  = $ps
        AsyncResult = $asyncResult
    }
}



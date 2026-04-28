# Debug log path - tee everything significant so failures in background runspaces are visible.
$script:TeaWebDebugLog = '/tmp/pstea-web-debug.log'

function Write-TeaWebDebug {
    <#
    .SYNOPSIS
        Appends a timestamped debug message to the web debug log.

    .DESCRIPTION
        Writes a line in '[HH:mm:ss.fff] <Message>' format to the path stored in
        $script:TeaWebDebugLog (/tmp/pstea-web-debug.log). Uses -ErrorAction SilentlyContinue
        so failures are silent in production. Called from Invoke-TeaWebSocketListener and
        its background runspaces.

    .PARAMETER Message
        The message text to append.
    #>
    [CmdletBinding()]
    param([string]$Message)
    $ts = [datetime]::Now.ToString('HH:mm:ss.fff')
    Add-Content -Path $script:TeaWebDebugLog -Value "[$ts] $Message" -ErrorAction SilentlyContinue
}

function Start-ElmProgram {
    <#
    .SYNOPSIS
        Starts an Elm-architecture program in the terminal.

    .DESCRIPTION
        Calls InitFn to obtain the initial model, creates a terminal driver to read
        keyboard input, runs the MVU event loop until a Quit command is returned, then
        tears down the driver and returns the final model.

        The three required scriptblocks mirror the Elm Architecture:
          - InitFn   : () -> { Model; Cmd }
          - UpdateFn : ($msg, $model) -> { Model; Cmd }
          - ViewFn   : ($model) -> view-tree node

    .PARAMETER InitFn
        Scriptblock with no parameters that returns a PSCustomObject with Model and Cmd
        properties. Cmd may be $null.

    .PARAMETER UpdateFn
        Scriptblock accepting ($msg, $model) that returns a PSCustomObject with Model
        and Cmd properties. Return Cmd.Type = 'Quit' to exit the event loop.

    .PARAMETER ViewFn
        Scriptblock accepting ($model) that returns a view-tree node (Type 'Text' or
        'Box') produced by New-ElmText, New-ElmBox, or New-ElmRow.

    .PARAMETER Width
        Terminal width in columns used for layout. Defaults to 80.

    .PARAMETER Height
        Terminal height in rows used for layout. Defaults to 24.

    .OUTPUTS
        PSCustomObject — the final model at the time the event loop exited.

    .EXAMPLE
        $init   = { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 0 }; Cmd = $null } }
        $update = { param($msg, $model)
            $newCount = if ($msg -eq 'Inc') { $model.Count + 1 } else { $model.Count }
            [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $newCount }; Cmd = $null }
        }
        $view   = { param($model) New-ElmText -Content "Count: $($model.Count)" }
        Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

    .NOTES
        Requires a terminal that supports ANSI escape sequences. On Windows, ensure
        Enable-VirtualTerminalProcessing has been called before invoking this function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$InitFn,

        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter()]
        [int]$Width = 80,

        [Parameter()]
        [int]$Height = 24
    )

    $driver = New-ElmTerminalDriver

    $initResult    = & $InitFn
    $initialModel  = $initResult.Model

    try {
        $finalModel = Invoke-ElmEventLoop `
            -InitialModel   $initialModel `
            -UpdateFn       $UpdateFn `
            -ViewFn         $ViewFn `
            -InputQueue     $driver.InputQueue `
            -TerminalWidth  $Width `
            -TerminalHeight $Height
    } finally {
        & $driver.Stop
    }

    return $finalModel
}

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
        Terminal width in columns used for layout. Defaults to the current terminal width
        ([Console]::WindowWidth). If the terminal reports no width (e.g. no TTY), falls
        back to 80. Must not exceed the actual terminal width - if it does, a terminating
        error is thrown with instructions to resize or omit the parameter.

    .PARAMETER Height
        Terminal height in rows used for layout. Defaults to the current terminal height
        ([Console]::WindowHeight). If the terminal reports no height, falls back to 24.
        Must not exceed the actual terminal height.

    .OUTPUTS
        PSCustomObject - the final model at the time the event loop exited.

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
        [int]$Width = 0,

        [Parameter()]
        [int]$Height = 0
    )

    # Resolve actual terminal dimensions, falling back if running without a TTY
    $termWidth  = if ([Console]::WindowWidth  -gt 0) { [Console]::WindowWidth  } else { 80 }
    $termHeight = if ([Console]::WindowHeight -gt 0) { [Console]::WindowHeight } else { 24 }

    # Validate explicit sizes - must fit in the real terminal
    if ($PSBoundParameters.ContainsKey('Width') -and $Width -gt $termWidth) {
        $ex  = [System.ArgumentOutOfRangeException]::new(
            'Width',
            "Requested width ($Width) exceeds terminal width ($termWidth). " +
            'Resize the terminal or omit -Width to fill the terminal automatically.'
        )
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'TerminalTooSmall',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Width
        )
        $PSCmdlet.ThrowTerminatingError($err)
    }
    if ($PSBoundParameters.ContainsKey('Height') -and $Height -gt $termHeight) {
        $ex  = [System.ArgumentOutOfRangeException]::new(
            'Height',
            "Requested height ($Height) exceeds terminal height ($termHeight). " +
            'Resize the terminal or omit -Height to fill the terminal automatically.'
        )
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'TerminalTooSmall',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Height
        )
        $PSCmdlet.ThrowTerminatingError($err)
    }

    $resolvedWidth  = if ($PSBoundParameters.ContainsKey('Width'))  { $Width  } else { $termWidth  }
    $resolvedHeight = if ($PSBoundParameters.ContainsKey('Height')) { $Height } else { $termHeight }

    $driver = New-ElmTerminalDriver -AltScreen

    $initResult    = & $InitFn
    $initialModel  = $initResult.Model

    try {
        $finalModel = Invoke-ElmEventLoop `
            -InitialModel   $initialModel `
            -UpdateFn       $UpdateFn `
            -ViewFn         $ViewFn `
            -InputQueue     $driver.InputQueue `
            -TerminalWidth  $resolvedWidth `
            -TerminalHeight $resolvedHeight
    } finally {
        & $driver.Stop
    }

    return $finalModel
}

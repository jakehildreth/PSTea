function Invoke-ElmEventLoop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InitialModel,

        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [scriptblock]$ViewFn,

        [Parameter(Mandatory)]
        [object]$InputQueue,

        [Parameter()]
        [int]$TerminalWidth = 80,

        [Parameter()]
        [int]$TerminalHeight = 24
    )

    $esc        = [char]27
    $hideCursor = $esc + '[?25l'
    $showCursor = $esc + '[?25h'

    $model    = $InitialModel
    $prevTree = $null

    [Console]::Write($hideCursor)
    try {
        # Initial render before any messages arrive
        $viewTree     = Invoke-ElmView -ViewFn $ViewFn -Model $model
        $measuredTree = Measure-ElmViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
        $patches      = @(Compare-ElmViewTree -OldTree $null -NewTree $measuredTree)
        $prevTree     = $measuredTree
        if ($patches.Count -gt 0) {
            [Console]::Write((ConvertTo-AnsiOutput -Root $measuredTree))
        }

        while ($true) {
            $msg = $null
            if ($InputQueue.TryDequeue([ref]$msg)) {
                $updateResult = Invoke-ElmUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
                $model = $updateResult.Model
                $cmd   = $updateResult.Cmd

                if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                    break
                }

                $viewTree     = Invoke-ElmView -ViewFn $ViewFn -Model $model
                $measuredTree = Measure-ElmViewTree -Root $viewTree -TermWidth $TerminalWidth -TermHeight $TerminalHeight
                $patches      = @(Compare-ElmViewTree -OldTree $prevTree -NewTree $measuredTree)
                $prevTree     = $measuredTree

                if ($patches.Count -gt 0) {
                    if ($patches[0].Type -eq 'FullRedraw') {
                        $ansiOutput = ConvertTo-AnsiOutput -Root $measuredTree
                    } else {
                        $ansiOutput = ConvertTo-AnsiPatch -Patches $patches
                    }
                    [Console]::Write($ansiOutput)
                }
            } else {
                [System.Threading.Thread]::Sleep(1)
            }
        }
    } finally {
        [Console]::Write($showCursor)
    }

    return $model
}

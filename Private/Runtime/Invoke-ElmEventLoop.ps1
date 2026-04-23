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

    $model = $InitialModel
    $prevTree = $null

    while ($true) {
        $msg = $null
        if ($InputQueue.TryDequeue([ref]$msg)) {
            $updateResult = Invoke-ElmUpdate -UpdateFn $UpdateFn -Message $msg -Model $model
            $model = $updateResult.Model
            $cmd = $updateResult.Cmd

            if ($null -ne $cmd -and $cmd.Type -eq 'Quit') {
                break
            }

            $viewTree = Invoke-ElmView -ViewFn $ViewFn -Model $model
            $measuredTree = Measure-ElmViewTree -Node $viewTree -AvailableWidth $TerminalWidth -AvailableHeight $TerminalHeight
            $patches = Compare-ElmViewTree -OldTree $prevTree -NewTree $measuredTree
            $prevTree = $measuredTree

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

    return $model
}

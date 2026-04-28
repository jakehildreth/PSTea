if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../PSTea.psd1" }

# ---------------------------------------------------------------------------
# System Monitor demo
# Live process table, auto-refreshing every 2 seconds via timer subscription.
# Demonstrates: timer-driven data polling, tabular rendering, sort/scroll.
#
# Controls:
#   UpArrow / K   - scroll up
#   DownArrow / J - scroll down
#   C             - sort by CPU
#   M             - sort by memory
#   R             - force refresh now
#   Q             - quit
# ---------------------------------------------------------------------------

$script:PAGE_SIZE = 10   # visible process rows

function Get-ProcessSnapshot {
    @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_ } |
        Select-Object -Property Id,
            @{ Name = 'Name';    Expression = { [string]$_.Name } },
            @{ Name = 'CpuSec';  Expression = { [math]::Round($_.CPU, 1) } },
            @{ Name = 'MemMB';   Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
            @{ Name = 'Threads'; Expression = { [int]$_.Threads.Count } })
}

function Sort-Processes {
    param([object[]]$Procs, [string]$SortBy)
    if ($SortBy -eq 'CPU') {
        @($Procs | Sort-Object -Property CpuSec -Descending)
    } else {
        @($Procs | Sort-Object -Property MemMB -Descending)
    }
}

$initFn = {
    $procs  = Get-ProcessSnapshot
    $sorted = Sort-Processes -Procs $procs -SortBy 'CPU'
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Processes    = $sorted
            SortBy       = 'CPU'
            ScrollOffset = 0
            RefreshedAt  = [datetime]::Now.ToString('HH:mm:ss')
        }
        Cmd = $null
    }
}

$updateFn = {
    param($msg, $model)

    switch ($msg) {
        'Refresh' {
            $procs  = Get-ProcessSnapshot
            $sorted = Sort-Processes -Procs $procs -SortBy $model.SortBy
            $newModel = [PSCustomObject]@{
                Processes    = $sorted
                SortBy       = $model.SortBy
                ScrollOffset = [math]::Min($model.ScrollOffset, [math]::Max(0, $sorted.Count - $script:PAGE_SIZE))
                RefreshedAt  = [datetime]::Now.ToString('HH:mm:ss')
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'SortByCpu' {
            $sorted = Sort-Processes -Procs $model.Processes -SortBy 'CPU'
            $newModel = [PSCustomObject]@{
                Processes    = $sorted
                SortBy       = 'CPU'
                ScrollOffset = 0
                RefreshedAt  = $model.RefreshedAt
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'SortByMem' {
            $sorted = Sort-Processes -Procs $model.Processes -SortBy 'Memory'
            $newModel = [PSCustomObject]@{
                Processes    = $sorted
                SortBy       = 'Memory'
                ScrollOffset = 0
                RefreshedAt  = $model.RefreshedAt
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'ScrollUp' {
            $newOffset = [math]::Max(0, $model.ScrollOffset - 1)
            $newModel = [PSCustomObject]@{
                Processes    = $model.Processes
                SortBy       = $model.SortBy
                ScrollOffset = $newOffset
                RefreshedAt  = $model.RefreshedAt
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'ScrollDown' {
            $maxOffset = [math]::Max(0, $model.Processes.Count - $script:PAGE_SIZE)
            $newOffset = [math]::Min($maxOffset, $model.ScrollOffset + 1)
            $newModel = [PSCustomObject]@{
                Processes    = $model.Processes
                SortBy       = $model.SortBy
                ScrollOffset = $newOffset
                RefreshedAt  = $model.RefreshedAt
            }
            return [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        'Quit' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

$viewFn = {
    param($model)

    $titleStyle  = New-TeaStyle -Foreground 'BrightCyan'   -Bold
    $headerStyle = New-TeaStyle -Foreground 'BrightWhite'  -Bold
    $rowStyle    = New-TeaStyle -Foreground 'White'
    $dimStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $sortStyle   = New-TeaStyle -Foreground 'BrightYellow'
    $hintStyle   = New-TeaStyle -Foreground 'BrightBlack'
    $sepStyle    = New-TeaStyle -Foreground 'BrightBlack'

    # Column widths: PID(6) Name(24) CPU(9) Mem(9) Threads(8)
    $fmt = '{0,-6} {1,-24} {2,9} {3,9} {4,8}'

    $header = $fmt -f 'PID', 'NAME', 'CPU(s)', 'MEM(MB)', 'THREADS'
    $sep    = '-' * 60

    $cpuLabel = if ($model.SortBy -eq 'CPU')    { '[C] CPU *' } else { '[C] CPU  ' }
    $memLabel = if ($model.SortBy -eq 'Memory') { '[M] Mem *' } else { '[M] Mem  ' }

    $children = [System.Collections.Generic.List[object]]::new()
    $children.Add((New-TeaText -Content "System Monitor  $($model.RefreshedAt)" -Style $titleStyle))
    $children.Add((New-TeaText -Content "Sort: $cpuLabel  $memLabel   $($model.Processes.Count) processes" -Style $sortStyle))
    $children.Add((New-TeaText -Content $sep    -Style $sepStyle))
    $children.Add((New-TeaText -Content $header -Style $headerStyle))
    $children.Add((New-TeaText -Content $sep    -Style $sepStyle))

    $procs = @($model.Processes)
    $end   = [math]::Min($model.ScrollOffset + $script:PAGE_SIZE, $procs.Count) - 1

    for ($i = $model.ScrollOffset; $i -le $end; $i++) {
        $p       = $procs[$i]
        $nameStr = [string]$p.Name
        $name    = if ($nameStr.Length -gt 24) { $nameStr.Substring(0, 23) + '~' } else { $nameStr }
        $line    = $fmt -f $p.Id, $name, $p.CpuSec, $p.MemMB, $p.Threads
        $children.Add((New-TeaText -Content $line -Style $rowStyle))
    }

    $shown = $end - $model.ScrollOffset + 1
    $blank = $script:PAGE_SIZE - [math]::Max(0, $shown)
    for ($i = 0; $i -lt $blank; $i++) {
        $children.Add((New-TeaText -Content ''))
    }

    $children.Add((New-TeaText -Content $sep -Style $sepStyle))

    $scrollInfo = "$($model.ScrollOffset + 1)-$($end + 1) of $($procs.Count)"
    $children.Add((New-TeaText -Content "[Up/K] [Dn/J] scroll  [R] refresh  [Q] quit   $scrollInfo" -Style $hintStyle))

    New-TeaBox -Children $children.ToArray()
}

$subFn = {
    param($model)
    @(
        New-TeaTimerSub -IntervalMs 2000 -Handler { 'Refresh'    }
        New-TeaKeySub   -Key 'Q'         -Handler { 'Quit'       }
        New-TeaKeySub   -Key 'R'         -Handler { 'Refresh'    }
        New-TeaKeySub   -Key 'C'         -Handler { 'SortByCpu'  }
        New-TeaKeySub   -Key 'M'         -Handler { 'SortByMem'  }
        New-TeaKeySub   -Key 'UpArrow'   -Handler { 'ScrollUp'   }
        New-TeaKeySub   -Key 'DownArrow' -Handler { 'ScrollDown' }
        New-TeaKeySub   -Key 'K'         -Handler { 'ScrollUp'   }
        New-TeaKeySub   -Key 'J'         -Handler { 'ScrollDown' }
    )
}

function Invoke-SystemMonitorDemo {
    <#
    .SYNOPSIS
        Live process monitor in the terminal.

    .DESCRIPTION
        Displays a sortable, scrollable table of running processes, auto-refreshing
        every 2 seconds via a timer subscription.

        Controls: Up/K scroll up, Down/J scroll down, C sort by CPU, M sort by
        memory, R force refresh, Q quit.

    .NOTES
        Requires the PSTea module. Run from Examples:
        . .\Invoke-SystemMonitorDemo.ps1; Invoke-SystemMonitorDemo
    #>
    [CmdletBinding()]
    param()

    Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subFn
}

Invoke-SystemMonitorDemo

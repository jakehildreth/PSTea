#Requires -Version 5.1
<#
.SYNOPSIS
    B-02: Hello, PSTea — static display with a quit handler.

.DESCRIPTION
    The simplest possible PSTea program. Demonstrates:
      - Start-TeaProgram anatomy (InitFn / UpdateFn / ViewFn)
      - New-TeaText and New-TeaBox as the two basic view building blocks
      - The Quit pattern: returning { Cmd = @{ Type = 'Quit' } } from Update
      - What happens at exit (alt screen dismissed, cursor restored)

    Keys:
      Q  - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/beginner/02-hello-pstea.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Message : greeting text
# Version : display version string
# Author  : your name here
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Message = 'Hello, PSTea!'
            Version = '1.0'
            Author  = 'You'
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    # NOTE: $msg.Key is a string matching the .NET ConsoleKey enum name.
    # 'Q' matches the Q key regardless of Shift state.
    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{
            Model = $model
            Cmd   = [PSCustomObject]@{ Type = 'Quit' }
        }
    }

    # NOTE: Always return an explicit result — returning $null causes an error.
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    # New-TeaBox stacks its children vertically (top to bottom).
    # New-TeaText is the leaf node — every visible character is ultimately a Text node.
    New-TeaBox -Children @(
        New-TeaText -Content $model.Message
        New-TeaText -Content "Version: $($model.Version)"
        New-TeaText -Content "Author:  $($model.Author)"
        New-TeaText -Content ''
        New-TeaText -Content '[Q] quit'
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

$finalModel = Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn

# Start-TeaProgram returns the final model after the loop exits.
# Back on the normal screen now — Write-Host is fine here.
Write-Host "Exited cleanly. Final model message: $($finalModel.Message)"

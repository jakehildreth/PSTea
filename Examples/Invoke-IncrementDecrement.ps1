Import-Module "$PSScriptRoot/../PSTea.psd1" -Force

$init = {
    [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = 0 }; Cmd = $null }
}

$update = {
    param($msg, $model)
    switch ($msg.Key) {
        'UpArrow'   { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $model.Count + 1 }; Cmd = $null } }
        'DownArrow' { [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $model.Count - 1 }; Cmd = $null } }
        'Q'         { [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } } }
        default     { [PSCustomObject]@{ Model = $model; Cmd = $null } }
    }
}

$view = {
    param($model)
    $hintStyle = New-TeaStyle -Foreground 'BrightBlack'
    New-TeaBox -Style (New-TeaStyle -Width 30 -Padding @(0, 1)) -Children @(
        New-TeaText -Content "Count: $($model.Count)"
        New-TeaText -Content '[Up] inc  [Down] dec  [Q] quit' -Style $hintStyle
    )
}

Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view
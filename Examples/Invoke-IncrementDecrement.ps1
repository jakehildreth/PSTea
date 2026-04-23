Import-Module "$PSScriptRoot/../Elm.psd1" -Force

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
    New-ElmBox -Style (New-ElmStyle -Width 30 -Padding @(0, 1)) -Children @(
        New-ElmText -Content "Count: $($model.Count)"
        New-ElmText -Content '[Up] inc  [Down] dec  [Q] quit'
    )
}

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view
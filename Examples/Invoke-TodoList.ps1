Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
# items  : list of @{ Text = '...'; Done = $false }
# cursor : index of the selected item
# ---------------------------------------------------------------------------

$init = {
    $items = @(
        @{ Text = 'Buy groceries';         Done = $false }
        @{ Text = 'Write unit tests';       Done = $false }
        @{ Text = 'Ship it';                Done = $false }
        @{ Text = 'Touch grass';            Done = $false }
        @{ Text = 'Feed the cat';           Done = $false }
    )
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Items = $items; Cursor = 0 }
        Cmd   = $null
    }
}

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

$update = {
    param($msg, $model)

    $items  = $model.Items
    $cursor = $model.Cursor
    $count  = $items.Count

    switch ($msg.Key) {
        'UpArrow' {
            $cursor = if ($cursor -gt 0) { $cursor - 1 } else { $count - 1 }
        }
        'DownArrow' {
            $cursor = if ($cursor -lt $count - 1) { $cursor + 1 } else { 0 }
        }
        'Spacebar' {
            # Toggle done on selected item - clone the array so the model is immutable-ish
            $newItems = @()
            for ($i = 0; $i -lt $count; $i++) {
                if ($i -eq $cursor) {
                    $newItems += @{ Text = $items[$i].Text; Done = -not $items[$i].Done }
                } else {
                    $newItems += $items[$i]
                }
            }
            $items = $newItems
        }
        'Q' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Items = $items; Cursor = $cursor }
        Cmd   = $null
    }
}

# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------

$view = {
    param($model)

    $titleStyle    = New-ElmStyle -Bold -Foreground 'BrightCyan'
    $hintStyle     = New-ElmStyle -Foreground 'BrightBlack'
    $selectedStyle = New-ElmStyle -Background 'Blue' -Foreground 'BrightWhite' -Bold
    $doneStyle     = New-ElmStyle -Foreground 'BrightBlack' -Strikethrough
    $normalStyle   = New-ElmStyle -Foreground 'White'
    $boxStyle      = New-ElmStyle -Border 'Rounded' -Padding @(0, 1) -Width 42

    $rows = @(
        New-ElmText -Content '  todo list' -Style $titleStyle
        New-ElmText -Content ''
    )

    for ($i = 0; $i -lt $model.Items.Count; $i++) {
        $item   = $model.Items[$i]
        $prefix = if ($item.Done) { '[x] ' } else { '[ ] ' }
        $label  = $prefix + $item.Text

        if ($i -eq $model.Cursor) {
            $rows += New-ElmText -Content "> $label" -Style $selectedStyle
        } elseif ($item.Done) {
            $rows += New-ElmText -Content "  $label" -Style $doneStyle
        } else {
            $rows += New-ElmText -Content "  $label" -Style $normalStyle
        }
    }

    $rows += New-ElmText -Content ''
    $rows += New-ElmText -Content '  [up/down] move  [space] toggle  [q] quit' -Style $hintStyle

    New-ElmBox -Style $boxStyle -Children $rows
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

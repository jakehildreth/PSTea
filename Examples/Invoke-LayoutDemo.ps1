Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Multi-pane layout demo
# Left panel: navigation menu (arrow keys + enter to switch)
# Right panel: content for the selected page
# Demonstrates: New-ElmRow, percentage widths, conditional view rendering
# ---------------------------------------------------------------------------

$pages = @(
    [PSCustomObject]@{
        Title   = 'Welcome'
        Content = @(
            'This demo shows a two-pane layout.'
            ''
            'The left panel is a nav menu.'
            'The right panel renders content'
            'based on the selected page.'
            ''
            'Arrow keys move the selection.'
            'Enter confirms.'
        )
    }
    [PSCustomObject]@{
        Title   = 'Layout'
        Content = @(
            'New-ElmRow arranges children'
            'horizontally.'
            ''
            'New-ElmBox arranges children'
            'vertically (the default).'
            ''
            'Width can be: Auto, Fill,'
            'an integer, or a percentage.'
        )
    }
    [PSCustomObject]@{
        Title   = 'Style'
        Content = @(
            'New-ElmStyle properties:'
            ''
            '  -Foreground / -Background'
            '  -Bold / -Italic'
            '  -Underline / -Strikethrough'
            '  -Border (None/Normal/Rounded'
            '           /Thick/Double)'
            '  -Padding / -Margin'
        )
    }
    [PSCustomObject]@{
        Title   = 'TEA'
        Content = @(
            'The Elm Architecture:'
            ''
            '  Init   -> initial model'
            '  Update -> msg + model'
            '              -> new model'
            '  View   -> model -> tree'
            ''
            'Pure scriptblocks. No side'
            'effects in Update or View.'
        )
    }
)

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

$init = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Pages    = $pages
            Selected = 0
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

$update = {
    param($msg, $model)

    $selected = $model.Selected
    $count    = $model.Pages.Count

    switch ($msg.Key) {
        'UpArrow'   { $selected = if ($selected -gt 0) { $selected - 1 } else { $count - 1 } }
        'DownArrow' { $selected = if ($selected -lt $count - 1) { $selected + 1 } else { 0 } }
        'Q'         {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Pages = $model.Pages; Selected = $selected }
        Cmd   = $null
    }
}

# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------

$view = {
    param($model)

    $navActiveStyle  = New-ElmStyle -Foreground 'BrightWhite' -Background 'Blue' -Bold
    $navNormalStyle  = New-ElmStyle -Foreground 'White'
    $headingStyle    = New-ElmStyle -Bold -Foreground 'BrightCyan'
    $contentStyle    = New-ElmStyle -Foreground 'White'
    $hintStyle       = New-ElmStyle -Foreground 'BrightBlack'
    $navPanelStyle   = New-ElmStyle -Border 'Normal' -Padding @(1, 1) -Width 18 -MarginRight 2
    $contentPanStyle = New-ElmStyle -Border 'Normal' -Padding @(1, 2) -Width 36

    # Left: nav menu
    $navItems = for ($i = 0; $i -lt $model.Pages.Count; $i++) {
        $page  = $model.Pages[$i]
        $label = if ($i -eq $model.Selected) { "> $($page.Title)" } else { "  $($page.Title)" }
        $style = if ($i -eq $model.Selected) { $navActiveStyle } else { $navNormalStyle }
        New-ElmText -Content $label -Style $style
    }
    $navItems += New-ElmText -Content ''
    $navItems += New-ElmText -Content '[up/down] move' -Style $hintStyle
    $navItems += New-ElmText -Content '[q] quit'       -Style $hintStyle

    $navPanel = New-ElmBox -Style $navPanelStyle -Children $navItems

    # Right: content for selected page
    $page    = $model.Pages[$model.Selected]
    $content = @(New-ElmText -Content $page.Title -Style $headingStyle)
    $content += New-ElmText -Content ''
    foreach ($line in $page.Content) {
        $content += New-ElmText -Content $line -Style $contentStyle
    }

    $contentPanel = New-ElmBox -Style $contentPanStyle -Children $content

    New-ElmRow -Children @($navPanel, $contentPanel)
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

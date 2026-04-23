Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Static showcase — no state changes, Q to quit
# Demonstrates: border styles, text decorations, foreground/background colors
# ---------------------------------------------------------------------------

$init = {
    [PSCustomObject]@{ Model = [PSCustomObject]@{}; Cmd = $null }
}

$update = {
    param($msg, $model)
    $cmd = if ($msg.Key -eq 'Q') { [PSCustomObject]@{ Type = 'Quit' } } else { $null }
    [PSCustomObject]@{ Model = $model; Cmd = $cmd }
}

$view = {
    param($model)

    # --- border styles ---
    $borders = @('None', 'Normal', 'Rounded', 'Thick', 'Double')
    $borderNodes = foreach ($b in $borders) {
        New-ElmBox -Style (New-ElmStyle -Border $b -Padding @(0, 1) -MarginRight 2) -Children @(
            New-ElmText -Content " $b "
        )
    }
    $borderRow = New-ElmRow -Children $borderNodes

    # --- text decorations ---
    $decoNodes = @(
        New-ElmText -Content ' Normal    ' -Style (New-ElmStyle)
        New-ElmText -Content ' Bold      ' -Style (New-ElmStyle -Bold)
        New-ElmText -Content ' Italic    ' -Style (New-ElmStyle -Italic)
        New-ElmText -Content ' Underline ' -Style (New-ElmStyle -Underline)
        New-ElmText -Content ' Strike    ' -Style (New-ElmStyle -Strikethrough)
    )
    $decoRow = New-ElmRow -Children $decoNodes

    # --- named foreground colors ---
    $namedColors = @('Black','Red','Green','Yellow','Blue','Magenta','Cyan','White',
                     'BrightBlack','BrightRed','BrightGreen','BrightYellow',
                     'BrightBlue','BrightMagenta','BrightCyan','BrightWhite')
    $colorNodes = foreach ($c in $namedColors) {
        New-ElmText -Content " $c " -Style (New-ElmStyle -Foreground $c)
    }
    $colorRow1 = New-ElmRow -Children $colorNodes[0..7]
    $colorRow2 = New-ElmRow -Children $colorNodes[8..15]

    # --- background colors ---
    $bgNodes = foreach ($c in @('Red','Green','Blue','Magenta','Cyan','Yellow')) {
        New-ElmText -Content "  $c  " -Style (New-ElmStyle -Background $c -Foreground 'Black')
    }
    $bgRow = New-ElmRow -Children $bgNodes

    # --- hex / 256-index samples ---
    $hexNodes = @(
        New-ElmText -Content ' #FF6B6B ' -Style (New-ElmStyle -Foreground '#FF6B6B')
        New-ElmText -Content ' #6BCB77 ' -Style (New-ElmStyle -Foreground '#6BCB77')
        New-ElmText -Content ' #4D96FF ' -Style (New-ElmStyle -Foreground '#4D96FF')
        New-ElmText -Content ' #FFD93D ' -Style (New-ElmStyle -Foreground '#FFD93D')
        New-ElmText -Content ' 196 '     -Style (New-ElmStyle -Foreground 196)
        New-ElmText -Content ' 46  '     -Style (New-ElmStyle -Foreground 46)
        New-ElmText -Content ' 21  '     -Style (New-ElmStyle -Foreground 21)
    )
    $hexRow = New-ElmRow -Children $hexNodes

    $headingStyle = New-ElmStyle -Bold -Foreground 'BrightCyan'
    $hintStyle    = New-ElmStyle -Foreground 'BrightBlack'
    $outerStyle   = New-ElmStyle -Border 'Rounded' -Padding @(1, 2)

    New-ElmBox -Style $outerStyle -Children @(
        New-ElmText -Content 'Elm Style Showcase' -Style $headingStyle
        New-ElmText -Content ''
        New-ElmText -Content 'Borders' -Style (New-ElmStyle -Underline)
        $borderRow
        New-ElmText -Content ''
        New-ElmText -Content 'Text Decorations' -Style (New-ElmStyle -Underline)
        $decoRow
        New-ElmText -Content ''
        New-ElmText -Content 'Named Foreground Colors' -Style (New-ElmStyle -Underline)
        $colorRow1
        $colorRow2
        New-ElmText -Content ''
        New-ElmText -Content 'Background Colors' -Style (New-ElmStyle -Underline)
        $bgRow
        New-ElmText -Content ''
        New-ElmText -Content 'Hex + 256-Index Colors' -Style (New-ElmStyle -Underline)
        $hexRow
        New-ElmText -Content ''
        New-ElmText -Content '[q] quit' -Style $hintStyle
    )
}

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

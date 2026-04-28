if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../PSTea.psd1" }

# ---------------------------------------------------------------------------
# Static showcase - no state changes, Q to quit
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
        New-TeaBox -Style (New-TeaStyle -Border $b -Padding @(0, 1) -MarginRight 2) -Children @(
            New-TeaText -Content " $b "
        )
    }
    $borderRow = New-TeaRow -Children $borderNodes

    # --- text decorations ---
    $decoNodes = @(
        New-TeaText -Content ' Normal    ' -Style (New-TeaStyle)
        New-TeaText -Content ' Bold      ' -Style (New-TeaStyle -Bold)
        New-TeaText -Content ' Italic    ' -Style (New-TeaStyle -Italic)
        New-TeaText -Content ' Underline ' -Style (New-TeaStyle -Underline)
        New-TeaText -Content ' Strike    ' -Style (New-TeaStyle -Strikethrough)
    )
    $decoRow = New-TeaRow -Children $decoNodes

    # --- named foreground colors ---
    $namedColors = @('Black','Red','Green','Yellow','Blue','Magenta','Cyan','White',
                     'BrightBlack','BrightRed','BrightGreen','BrightYellow',
                     'BrightBlue','BrightMagenta','BrightCyan','BrightWhite')
    $colorNodes = foreach ($c in $namedColors) {
        New-TeaText -Content " $c " -Style (New-TeaStyle -Foreground $c)
    }
    $colorRow1 = New-TeaRow -Children $colorNodes[0..7]
    $colorRow2 = New-TeaRow -Children $colorNodes[8..15]

    # --- background colors ---
    $bgNodes = foreach ($c in @('Red','Green','Blue','Magenta','Cyan','Yellow')) {
        New-TeaText -Content "  $c  " -Style (New-TeaStyle -Background $c -Foreground 'Black')
    }
    $bgRow = New-TeaRow -Children $bgNodes

    # --- hex / 256-index samples ---
    $hexNodes = @(
        New-TeaText -Content ' #FF6B6B ' -Style (New-TeaStyle -Foreground '#FF6B6B')
        New-TeaText -Content ' #6BCB77 ' -Style (New-TeaStyle -Foreground '#6BCB77')
        New-TeaText -Content ' #4D96FF ' -Style (New-TeaStyle -Foreground '#4D96FF')
        New-TeaText -Content ' #FFD93D ' -Style (New-TeaStyle -Foreground '#FFD93D')
        New-TeaText -Content ' 196 '     -Style (New-TeaStyle -Foreground 196)
        New-TeaText -Content ' 46  '     -Style (New-TeaStyle -Foreground 46)
        New-TeaText -Content ' 21  '     -Style (New-TeaStyle -Foreground 21)
    )
    $hexRow = New-TeaRow -Children $hexNodes

    $headingStyle = New-TeaStyle -Bold -Foreground 'BrightCyan'
    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $outerStyle   = New-TeaStyle -Border 'Rounded' -Padding @(1, 2)

    New-TeaBox -Style $outerStyle -Children @(
        New-TeaText -Content 'PSTea Style Showcase' -Style $headingStyle
        New-TeaText -Content ''
        New-TeaText -Content 'Borders' -Style (New-TeaStyle -Underline)
        $borderRow
        New-TeaText -Content ''
        New-TeaText -Content 'Text Decorations' -Style (New-TeaStyle -Underline)
        $decoRow
        New-TeaText -Content ''
        New-TeaText -Content 'Named Foreground Colors' -Style (New-TeaStyle -Underline)
        $colorRow1
        $colorRow2
        New-TeaText -Content ''
        New-TeaText -Content 'Background Colors' -Style (New-TeaStyle -Underline)
        $bgRow
        New-TeaText -Content ''
        New-TeaText -Content 'Hex + 256-Index Colors' -Style (New-TeaStyle -Underline)
        $hexRow
        New-TeaText -Content ''
        New-TeaText -Content '[q] quit' -Style $hintStyle
    )
}

Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view

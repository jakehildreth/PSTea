#Requires -Version 5.1
<#
.SYNOPSIS
    B-04: Styling and Layout — borders, colors, and multi-column layouts.

.DESCRIPTION
    Demonstrates:
      - New-TeaStyle: Foreground, Background, Bold, Italic, Underline, Strikethrough
      - Border styles: None / Normal / Rounded / Thick / Double
      - Padding (inside border) vs Margin (outside border)
      - New-TeaBox (vertical stack) vs New-TeaRow (horizontal stack)
      - Composing nested boxes + rows for two-column layouts

    This is a static display (no interactivity beyond quitting).
    Keys:
      Q  - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/beginner/04-styling-and-layout.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Static demo — model only holds the page title. No user state needed.
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Title = 'Styling & Layout Demo' }
        Cmd   = $null
    }
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)
    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
    }
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $titleStyle   = New-TeaStyle -Foreground 'BrightCyan'  -Bold
    $headingStyle = New-TeaStyle -Foreground 'BrightWhite' -Underline

    # -------------------------------------------------------------------
    # Left panel: text decoration + color showcase
    # -------------------------------------------------------------------
    $leftBoxStyle = New-TeaStyle -Border 'Rounded' -Padding @(1, 2) -Width 30

    $leftPanel = New-TeaBox -Style $leftBoxStyle -Children @(
        New-TeaText -Content 'Text Decorations'             -Style $headingStyle
        New-TeaText -Content ''
        New-TeaText -Content 'Normal text'
        New-TeaText -Content 'Bold text'                    -Style (New-TeaStyle -Bold)
        New-TeaText -Content 'Italic text'                  -Style (New-TeaStyle -Italic)
        New-TeaText -Content 'Underline text'               -Style (New-TeaStyle -Underline)
        New-TeaText -Content 'Strikethrough text'           -Style (New-TeaStyle -Strikethrough)
        New-TeaText -Content ''
        New-TeaText -Content 'Colors'                       -Style $headingStyle
        New-TeaText -Content ''
        New-TeaText -Content 'BrightRed'                    -Style (New-TeaStyle -Foreground 'BrightRed')
        New-TeaText -Content 'BrightGreen'                  -Style (New-TeaStyle -Foreground 'BrightGreen')
        New-TeaText -Content 'BrightYellow'                 -Style (New-TeaStyle -Foreground 'BrightYellow')
        New-TeaText -Content 'BrightBlue'                   -Style (New-TeaStyle -Foreground 'BrightBlue')
        New-TeaText -Content 'BrightMagenta'                -Style (New-TeaStyle -Foreground 'BrightMagenta')
        New-TeaText -Content 'BrightCyan'                   -Style (New-TeaStyle -Foreground 'BrightCyan')
        New-TeaText -Content 'BrightWhite'                  -Style (New-TeaStyle -Foreground 'BrightWhite')
        New-TeaText -Content 'BrightBlack (dark grey)'      -Style (New-TeaStyle -Foreground 'BrightBlack')
        New-TeaText -Content 'Background highlight'         -Style (New-TeaStyle -Foreground 'Black' -Background 'BrightCyan')
    )

    # -------------------------------------------------------------------
    # Middle panel: border style showcase
    # NOTE: MarginLeft adds space between the left panel and this one.
    # -------------------------------------------------------------------
    $middleBoxStyle = New-TeaStyle -Padding @(1, 2) -Width 26 -MarginLeft 2

    $middlePanel = New-TeaBox -Style $middleBoxStyle -Children @(
        New-TeaText -Content 'Border Styles'                -Style $headingStyle
        New-TeaText -Content ''
        New-TeaBox -Style (New-TeaStyle -Border 'Normal'  -Padding @(0, 1) -Width 22) -Children @(
            New-TeaText -Content 'Normal border'
        )
        New-TeaText -Content ''
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Padding @(0, 1) -Width 22) -Children @(
            New-TeaText -Content 'Rounded border'
        )
        New-TeaText -Content ''
        New-TeaBox -Style (New-TeaStyle -Border 'Thick'   -Padding @(0, 1) -Width 22) -Children @(
            New-TeaText -Content 'Thick border'
        )
        New-TeaText -Content ''
        New-TeaBox -Style (New-TeaStyle -Border 'Double'  -Padding @(0, 1) -Width 22) -Children @(
            New-TeaText -Content 'Double border'
        )
        New-TeaText -Content ''
        New-TeaText -Content 'Padding vs Margin'            -Style $headingStyle
        New-TeaText -Content ''
        # NOTE: Padding is INSIDE the border; Margin is OUTSIDE.
        New-TeaBox -Style (New-TeaStyle -Border 'Normal' -Padding @(1, 2) -Width 22) -Children @(
            New-TeaText -Content 'Padding: @(1,2)'
        )
        New-TeaText -Content ''
        New-TeaBox -Style (New-TeaStyle -Border 'Normal' -Margin 1 -Width 22) -Children @(
            New-TeaText -Content 'Margin: 1'
        )
    )

    # -------------------------------------------------------------------
    # Compose: New-TeaRow places panels side by side (left to right)
    # -------------------------------------------------------------------
    New-TeaBox -Children @(
        New-TeaText -Content $model.Title -Style $titleStyle
        New-TeaText -Content ''
        New-TeaRow -Children @($leftPanel, $middlePanel)
        New-TeaText -Content ''
        New-TeaText -Content '[Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn

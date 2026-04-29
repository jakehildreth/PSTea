#Requires -Version 5.1
<#
.SYNOPSIS
    A-02: Power Widgets — tabbed showcase of all six advanced view widgets.

.DESCRIPTION
    Demonstrates:
      - New-TeaProgressBar (-Value and -Percent)
      - New-TeaSpinner (frame counter, variants: Dots/Braille/Bounce/Arrow)
      - New-TeaTable (headers, rows, selected row, column widths)
      - New-TeaViewport (scrollable line window)
      - New-TeaTextarea (multi-line text, cursor tracking)
      - New-TeaPaginator (numeric, dots, and tabs modes)
      - New-TeaTimerSub for spinner animation and progress ticking
      - Tab navigation: P/N or Left/Right arrows

    Six panels, one per widget.

    Keys:
      N / Right  - next tab
      P / Left   - previous tab
      Up / Down  - scroll (Viewport panel) or navigate (Table panel)
      Q          - quit

.NOTES
    Run from the repo root:
        pwsh docs/tutorial/advanced/02-power-widgets.ps1
#>

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }

# ---------------------------------------------------------------------------
# DATA
# ---------------------------------------------------------------------------

$tableData = @(
    @('Alice',   '30', 'New York',  'Engineer')
    @('Bob',     '25', 'London',    'Designer')
    @('Charlie', '35', 'Berlin',    'Manager')
    @('Diana',   '28', 'Tokyo',     'Developer')
    @('Evan',    '42', 'Sydney',    'Architect')
)

$viewportLines = @(
    '# PSTea viewport demo'
    ''
    'This panel shows New-TeaViewport: a fixed-height window'
    'into an array of text lines. The caller tracks ScrollOffset.'
    ''
    'Scroll Down with the Down arrow key.'
    'Scroll Up with the Up arrow key.'
    ''
    'Line 9'
    'Line 10'
    'Line 11'
    'Line 12'
    'Line 13 - almost done'
    'Line 14 - last line'
)

$tabs = @('Progress', 'Spinner', 'Table', 'Viewport', 'Textarea', 'Paginator')

# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Tab           = 0                  # active tab index 0-5
            Frame         = 0                  # spinner frame counter
            Progress      = 0.0               # progress bar fill (0.0-1.0)
            TableCursor   = 0                  # table selected row
            ScrollOffset  = 0                  # viewport scroll position
            TextareaLines = @('Hello', 'World')  # textarea content
            CursorRow     = 0
            CursorCol     = 0
        }
        Cmd = $null
    }
}

# ---------------------------------------------------------------------------
# SUBSCRIPTIONS
# ---------------------------------------------------------------------------

$subscriptionFn = {
    param($model)
    @(
        New-TeaKeySub -Key 'N'          -Handler { 'NextTab' }
        New-TeaKeySub -Key 'P'          -Handler { 'PrevTab' }
        New-TeaKeySub -Key 'RightArrow' -Handler { 'NextTab' }
        New-TeaKeySub -Key 'LeftArrow'  -Handler { 'PrevTab' }
        New-TeaKeySub -Key 'UpArrow'    -Handler { 'ScrollUp' }
        New-TeaKeySub -Key 'DownArrow'  -Handler { 'ScrollDown' }
        New-TeaKeySub -Key 'Q'          -Handler { 'Quit' }
        # Timer drives spinner frame and progress bar
        New-TeaTimerSub -IntervalMs 80  -Handler { 'Tick' }
    )
}

# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)

    switch ($msg) {
        'Tick' {
            # Advance spinner frame unconditionally
            $newFrame = $model.Frame + 1
            # Advance progress bar (reset when full)
            $newProg  = if ($model.Progress -ge 1.0) { 0.0 } else { $model.Progress + 0.02 }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tab           = $model.Tab
                    Frame         = $newFrame
                    Progress      = $newProg
                    TableCursor   = $model.TableCursor
                    ScrollOffset  = $model.ScrollOffset
                    TextareaLines = $model.TextareaLines
                    CursorRow     = $model.CursorRow
                    CursorCol     = $model.CursorCol
                }
                Cmd = $null
            }
        }
        'NextTab' {
            $tabCount = ($using:tabs).Count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tab           = ($model.Tab + 1) % $tabCount
                    Frame         = $model.Frame
                    Progress      = $model.Progress
                    TableCursor   = $model.TableCursor
                    ScrollOffset  = 0   # reset scroll when switching tabs
                    TextareaLines = $model.TextareaLines
                    CursorRow     = $model.CursorRow
                    CursorCol     = $model.CursorCol
                }
                Cmd = $null
            }
        }
        'PrevTab' {
            $tabCount = ($using:tabs).Count
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tab           = ($model.Tab - 1 + $tabCount) % $tabCount
                    Frame         = $model.Frame
                    Progress      = $model.Progress
                    TableCursor   = $model.TableCursor
                    ScrollOffset  = 0
                    TextareaLines = $model.TextareaLines
                    CursorRow     = $model.CursorRow
                    CursorCol     = $model.CursorCol
                }
                Cmd = $null
            }
        }
        'ScrollDown' {
            $maxLines  = ($using:viewportLines).Count
            $maxOffset = [Math]::Max(0, $maxLines - 8)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tab           = $model.Tab
                    Frame         = $model.Frame
                    Progress      = $model.Progress
                    TableCursor   = [Math]::Min($model.TableCursor + 1, ($using:tableData).Count - 1)
                    ScrollOffset  = [Math]::Min($model.ScrollOffset + 1, $maxOffset)
                    TextareaLines = $model.TextareaLines
                    CursorRow     = $model.CursorRow
                    CursorCol     = $model.CursorCol
                }
                Cmd = $null
            }
        }
        'ScrollUp' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Tab           = $model.Tab
                    Frame         = $model.Frame
                    Progress      = $model.Progress
                    TableCursor   = [Math]::Max($model.TableCursor - 1, 0)
                    ScrollOffset  = [Math]::Max($model.ScrollOffset - 1, 0)
                    TextareaLines = $model.TextareaLines
                    CursorRow     = $model.CursorRow
                    CursorCol     = $model.CursorCol
                }
                Cmd = $null
            }
        }
        'Quit' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
        default {
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
    }
}

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)

    $hintStyle = New-TeaStyle -Foreground 'BrightBlack'
    $tabBar    = New-TeaPaginator -Tabs $using:tabs -ActiveTab $model.Tab `
                    -ActiveStyle (New-TeaStyle -Foreground 'BrightCyan' -Bold) `
                    -Style       (New-TeaStyle -Foreground 'BrightBlack')

    # --- Per-tab panel content ---
    $panel = switch ($model.Tab) {
        0 {
            # Progress bar
            $pct = [int]($model.Progress * 100)
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 40 -Padding @(1, 2)) -Children @(
                New-TeaText -Content 'Progress Bar'       -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
                New-TeaText -Content ''
                New-TeaProgressBar -Percent $pct -Width 34 -Style (New-TeaStyle -Foreground 'BrightGreen')
                New-TeaText -Content "  $pct%"             -Style (New-TeaStyle -Foreground 'BrightWhite')
                New-TeaText -Content ''
                New-TeaText -Content 'Loops automatically when it reaches 100%.' -Style $hintStyle
            )
        }
        1 {
            # Spinner
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 40 -Padding @(1, 2)) -Children @(
                New-TeaText -Content 'Spinner Variants'  -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
                New-TeaText -Content ''
                New-TeaRow -Children @(
                    New-TeaSpinner -Frame $model.Frame -Variant 'Dots'
                    New-TeaText -Content '  Dots (default)'
                )
                New-TeaRow -Children @(
                    New-TeaSpinner -Frame $model.Frame -Variant 'Braille' -Style (New-TeaStyle -Foreground 'BrightCyan')
                    New-TeaText -Content '  Braille'
                )
                New-TeaRow -Children @(
                    New-TeaSpinner -Frame $model.Frame -Variant 'Bounce' -Style (New-TeaStyle -Foreground 'BrightYellow')
                    New-TeaText -Content '  Bounce'
                )
                New-TeaRow -Children @(
                    New-TeaSpinner -Frame $model.Frame -Variant 'Arrow' -Style (New-TeaStyle -Foreground 'BrightGreen')
                    New-TeaText -Content '  Arrow'
                )
            )
        }
        2 {
            # Table
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 52 -Padding @(0, 1)) -Children @(
                New-TeaTable `
                    -Headers       @('Name', 'Age', 'City', 'Role') `
                    -Rows          $using:tableData `
                    -SelectedRow   $model.TableCursor `
                    -HeaderStyle   (New-TeaStyle -Foreground 'BrightCyan' -Bold) `
                    -SelectedStyle (New-TeaStyle -Foreground 'BrightYellow')
            )
        }
        3 {
            # Viewport
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 50 -Padding @(0, 1)) -Children @(
                New-TeaViewport `
                    -Lines        $using:viewportLines `
                    -ScrollOffset $model.ScrollOffset `
                    -MaxVisible   8 `
                    -Style        (New-TeaStyle -Foreground 'White')
            )
        }
        4 {
            # Textarea
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 42 -Padding @(0, 1)) -Children @(
                New-TeaText -Content 'Textarea (read-only demo)' -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
                New-TeaText -Content ''
                New-TeaTextarea `
                    -Lines           $model.TextareaLines `
                    -CursorRow       $model.CursorRow `
                    -CursorCol       $model.CursorCol `
                    -MaxVisible      6 `
                    -FocusedBoxStyle (New-TeaStyle -Border 'Normal' -Foreground 'BrightBlack')
            )
        }
        5 {
            # Paginator — all three modes
            New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 40 -Padding @(1, 2)) -Children @(
                New-TeaText -Content 'Paginator Modes' -Style (New-TeaStyle -Foreground 'BrightCyan' -Bold)
                New-TeaText -Content ''
                New-TeaText -Content 'Numeric:' -Style $hintStyle
                New-TeaPaginator -CurrentPage ($model.Tab + 1) -PageCount ($using:tabs).Count
                New-TeaText -Content ''
                New-TeaText -Content 'Dots:' -Style $hintStyle
                New-TeaPaginator -CurrentPage ($model.Tab + 1) -PageCount ($using:tabs).Count -Dots
                New-TeaText -Content ''
                New-TeaText -Content 'Tabs:' -Style $hintStyle
                New-TeaPaginator `
                    -Tabs        $using:tabs `
                    -ActiveTab   $model.Tab `
                    -ActiveStyle (New-TeaStyle -Foreground 'BrightCyan' -Bold) `
                    -Style       (New-TeaStyle -Foreground 'BrightBlack')
            )
        }
    }

    New-TeaBox -Children @(
        $tabBar
        New-TeaText -Content ''
        $panel
        New-TeaText -Content ''
        New-TeaText -Content '[N/Right] next  [P/Left] prev  [Up/Down] scroll/navigate  [Q] quit' -Style $hintStyle
    )
}

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------

Start-TeaProgram `
    -InitFn         $initFn `
    -UpdateFn       $updateFn `
    -ViewFn         $viewFn `
    -SubscriptionFn $subscriptionFn

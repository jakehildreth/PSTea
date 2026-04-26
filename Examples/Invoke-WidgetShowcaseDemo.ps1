Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Widget Showcase demo
# Demonstrates all five Phase 9 widgets with live-adjustable configuration.
# Each panel exposes widget params as keybindings — cycle options and see
# the widget update in real time.
#
# Navigation:
#   P / N        — previous / next panel
#   Q            — quit
#
# Panel 1 — Animation  (New-ElmSpinner + New-ElmProgressBar)
#   W  cycle -Width         (20/30/40)
#   F  cycle -FilledChar    (#/=/*/+)
#   E  cycle -EmptyChar     (-/./spc)
#
# Panel 2 — List  (New-ElmList)
#   Up/Down  navigate                M  cycle -MaxVisible  (5/8/10)
#   V        cycle -Prefix           (> / * / | / ->)
#
# Panel 3 — Viewport  (New-ElmViewport)
#   Up/Down  scroll                  M  cycle -MaxVisible  (4/8/12/16)
#
# Panel 4 — TextInput  (New-ElmTextInput)
#   Left/Right  cursor               F  toggle -Focused    (on/off)
#   Backspace   delete               C  cycle -CursorChar  (|/_/#)
# ---------------------------------------------------------------------------

$script:PANEL_COUNT = 7

# Config option arrays — indices stored in the model
$script:BAR_WIDTHS    = @(20, 30, 40)
$script:FILLED_CHARS  = @('#', '=', '*', '+')
$script:EMPTY_CHARS   = @('-', '.', ' ')
$script:LIST_MAX_VIS  = @(5, 8, 10)
$script:LIST_PREFIXES = @(
    [PSCustomObject]@{ Sel = '> '; Unsel = '  ' }
    [PSCustomObject]@{ Sel = '* '; Unsel = '  ' }
    [PSCustomObject]@{ Sel = '| '; Unsel = '  ' }
    [PSCustomObject]@{ Sel = '->'; Unsel = '  ' }
)
$script:VP_MAX_VIS    = @(4, 8, 12, 16)
$script:CURSOR_CHARS  = @('|', '_', '#')

# Phase 10 config
$script:TA_MAX_VIS     = @(4, 8, 12, 16)
$script:PAGER_MODES    = @('Numeric', 'Tabs', 'Dots')
$script:PAGER_PAGES    = 7
$script:PAGER_TAB_LABELS = @('Animate','List','Viewport','Input','Textarea','Table','Paginator')

# Table widget reference data
$script:TABLE_HEADERS = @('Widget', 'Returns', 'Key Params')
$script:TABLE_ROWS    = @(
    ,@('New-ElmProgressBar', 'Text',        '-Value/-Percent, -Width')
    ,@('New-ElmSpinner',     'Text',        '-Frame, -Variant')
    ,@('New-ElmList',        'Box/Vertical','-Items, -SelectedIndex')
    ,@('New-ElmViewport',    'Box/Vertical','-Lines, -ScrollOffset')
    ,@('New-ElmTextInput',   'Text/Box',    '-Value, -CursorPos, -FocusedStyle, -FocusedBoxStyle')
    ,@('New-ElmTextarea',    'Box/Vertical','-Lines, -CursorRow/-Col, -FocusedStyle, -FocusedBoxStyle')
    ,@('New-ElmTable',       'Box/Vertical','-Headers, -Rows')
    ,@('New-ElmPaginator',   'Text/Box',    '-CurrentPage / -Tabs / -Dots')
)

# Viewport content: one line per Phase 9 widget description
$script:VIEWPORT_LINES = @(
    'Phase 9 Widget Library — Elm for PowerShell'
    '============================================'
    ''
    'New-ElmProgressBar'
    '  Horizontal progress bar.'
    '  -Value 0.0..1.0 or -Percent 0..100'
    '  -Width (min 4), -FilledChar, -EmptyChar'
    '  Returns a Text node: [###-------]'
    ''
    'New-ElmSpinner'
    '  Animated spinner driven by a frame counter.'
    '  -Frame (caller increments), -Variant:'
    '    Dots   |  /  -  \  (default)'
    '    Braille  10 braille chars'
    '    Bounce  .  o  O  o'
    '    Arrow   >  >>  >>>'
    '  -Frames for a fully custom sequence.'
    ''
    'New-ElmList'
    '  Scrollable, selectable list of strings.'
    '  -Items, -SelectedIndex, -MaxVisible'
    '  -Prefix (selected), -UnselectedPrefix'
    '  -Style, -SelectedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-ElmViewport'
    '  Fixed-height window into a string array.'
    '  -Lines, -ScrollOffset, -MaxVisible, -Style'
    '  Clamps scroll offset automatically.'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-ElmTextInput'
    '  Single-line text input with cursor.'
    '  -Value, -CursorPos, -Focused (switch)'
    '  -Placeholder shown when empty+unfocused.'
    '  -CursorChar (default |)'
    '  -Style, -FocusedStyle'
    '  Returns a Text node.'
    ''
    'New-ElmTextarea'
    '  Multi-line text area with cursor.'
    '  -Lines [string[]], -CursorRow, -CursorCol'
    '  -Focused (switch), -MaxVisible, -ScrollOffset'
    '  -Placeholder, -CursorChar, -Style, -FocusedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-ElmTable'
    '  Data table with optional headers and row selection.'
    '  -Headers [string[]], -Rows [object[]]'
    '  -SelectedRow (-1 = no selection), -ColumnWidths'
    '  -Style, -HeaderStyle, -SelectedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-ElmPaginator'
    '  Numeric page indicator or named tab bar.'
    '  Numeric: -CurrentPage, -PageCount'
    '    renders: < 3 / 7 >'
    '  Tabs:    -Tabs [string[]], -ActiveTab'
    '    renders: Tab1 | [Tab2] | Tab3'
    '  -Style, -ActiveStyle'
    '  Returns Text (Numeric) or Box/Horizontal (Tabs).'
)

# List panel items
$script:COLOR_NAMES = @(
    'BrightRed'
    'BrightGreen'
    'BrightYellow'
    'BrightBlue'
    'BrightMagenta'
    'BrightCyan'
    'BrightWhite'
    'Red'
    'Green'
    'Yellow'
    'Blue'
    'Magenta'
    'Cyan'
    'White'
    'BrightBlack'
    'Black'
)

# Helper — shallow-copy model, optionally overriding specific fields
function New-ShowcaseModel {
    param($Model, [hashtable]$Overrides = @{})
    $m = [PSCustomObject]@{
        Tab           = $Model.Tab
        Frame         = $Model.Frame
        Progress      = $Model.Progress
        ListCursor    = $Model.ListCursor
        ViewOffset    = $Model.ViewOffset
        InputValue    = $Model.InputValue
        InputCursor   = $Model.InputCursor
        InputFocused  = $Model.InputFocused
        BarWidthIdx   = $Model.BarWidthIdx
        FilledCharIdx = $Model.FilledCharIdx
        EmptyCharIdx  = $Model.EmptyCharIdx
        ListMaxVisIdx = $Model.ListMaxVisIdx
        ListPrefixIdx = $Model.ListPrefixIdx
        VpMaxVisIdx   = $Model.VpMaxVisIdx
        CursorCharIdx = $Model.CursorCharIdx
        # Phase 10 fields
        TextareaLines     = $Model.TextareaLines
        TextareaRow       = $Model.TextareaRow
        TextareaCol       = $Model.TextareaCol
        TextareaOffset    = $Model.TextareaOffset
        TextareaFocused   = $Model.TextareaFocused
        TextareaCursorIdx = $Model.TextareaCursorIdx
        TextareaMaxVisIdx = $Model.TextareaMaxVisIdx
        TableCursor       = $Model.TableCursor
        PagerPage         = $Model.PagerPage
        PagerTabIdx       = $Model.PagerTabIdx
        PagerModeIdx      = $Model.PagerModeIdx
    }
    foreach ($key in $Overrides.Keys) { $m.$key = $Overrides[$key] }
    $m
}

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Tab           = 0        # 0=Animation 1=List 2=Viewport 3=TextInput
            Frame         = 0        # spinner frame counter
            Progress      = 0.0      # 0.0..1.0 progress bar value
            ListCursor    = 0        # selected list item
            ViewOffset    = 0        # viewport scroll offset
            InputValue    = ''
            InputCursor   = 0
            InputFocused  = $false    # TextInput -Focused state
            BarWidthIdx   = 1        # index into BAR_WIDTHS (default: 30)
            FilledCharIdx = 0        # index into FILLED_CHARS (default: #)
            EmptyCharIdx  = 0        # index into EMPTY_CHARS (default: -)
            ListMaxVisIdx = 2        # index into LIST_MAX_VIS (default: 10)
            ListPrefixIdx = 0        # index into LIST_PREFIXES (default: '> ')
            VpMaxVisIdx   = 2        # index into VP_MAX_VIS (default: 12)
            CursorCharIdx = 0        # index into CURSOR_CHARS (default: |)
            # Phase 10 fields
            TextareaLines     = [string[]]@('')
            TextareaRow       = 0    # cursor row (0-based)
            TextareaCol       = 0    # cursor col (0-based)
            TextareaOffset    = 0    # scroll offset
            TextareaFocused   = $false
            TextareaCursorIdx = 0    # index into CURSOR_CHARS
            TextareaMaxVisIdx = 1    # index into TA_MAX_VIS (default: 8)
            TableCursor       = 0    # selected row in table panel
            PagerPage         = 1    # current page (1-based, max = PAGER_PAGES)
            PagerTabIdx       = 0    # active tab in tab-mode paginator
            PagerModeIdx      = 0    # 0 = Numeric, 1 = Tabs
        }
        Cmd = $null
    }
}

$updateFn = {
    param($msg, $model)

    switch -Wildcard ($msg) {
        'Tick' {
            $newProgress = $model.Progress + 0.02
            if ($newProgress -gt 1.0) { $newProgress = 0.0 }
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ Frame = $model.Frame + 1; Progress = $newProgress }
                Cmd   = $null
            }
        }
        'TabNext' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ Tab = [math]::Min($model.Tab + 1, $script:PANEL_COUNT - 1) }
                Cmd   = $null
            }
        }
        'TabPrev' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ Tab = [math]::Max($model.Tab - 1, 0) }
                Cmd   = $null
            }
        }
        'ListUp' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ListCursor = [math]::Max($model.ListCursor - 1, 0) }
                Cmd   = $null
            }
        }
        'ListDown' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ListCursor = [math]::Min($model.ListCursor + 1, $script:COLOR_NAMES.Count - 1) }
                Cmd   = $null
            }
        }
        'ViewUp' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ViewOffset = [math]::Max($model.ViewOffset - 1, 0) }
                Cmd   = $null
            }
        }
        'ViewDown' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ViewOffset = [math]::Min($model.ViewOffset + 1, $script:VIEWPORT_LINES.Count - 1) }
                Cmd   = $null
            }
        }
        'InputLeft' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputCursor = [math]::Max($model.InputCursor - 1, 0) }
                Cmd   = $null
            }
        }
        'InputRight' {
            $maxPos = ([string]$model.InputValue).Length
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputCursor = [math]::Min($model.InputCursor + 1, $maxPos) }
                Cmd   = $null
            }
        }
        'Backspace' {
            $val    = [string]$model.InputValue
            $curPos = [math]::Max(0, [math]::Min($model.InputCursor, $val.Length))
            if ($curPos -eq 0) {
                return [PSCustomObject]@{ Model = $model; Cmd = $null }
            }
            $newVal = $val.Substring(0, $curPos - 1) + $val.Substring($curPos)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputValue = $newVal; InputCursor = $curPos - 1 }
                Cmd   = $null
            }
        }

        # --- config cycling ---
        'BarWidthCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ BarWidthIdx = ($model.BarWidthIdx + 1) % $script:BAR_WIDTHS.Count }
                Cmd   = $null
            }
        }
        'FilledCharCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ FilledCharIdx = ($model.FilledCharIdx + 1) % $script:FILLED_CHARS.Count }
                Cmd   = $null
            }
        }
        'EmptyCharCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ EmptyCharIdx = ($model.EmptyCharIdx + 1) % $script:EMPTY_CHARS.Count }
                Cmd   = $null
            }
        }
        'ListMaxVisCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ListMaxVisIdx = ($model.ListMaxVisIdx + 1) % $script:LIST_MAX_VIS.Count }
                Cmd   = $null
            }
        }
        'ListPrefixCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ ListPrefixIdx = ($model.ListPrefixIdx + 1) % $script:LIST_PREFIXES.Count }
                Cmd   = $null
            }
        }
        'VpMaxVisCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ VpMaxVisIdx = ($model.VpMaxVisIdx + 1) % $script:VP_MAX_VIS.Count }
                Cmd   = $null
            }
        }
        'InputToggleFocus' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputFocused = (-not $model.InputFocused) }
                Cmd   = $null
            }
        }
        'CursorCharCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ CursorCharIdx = ($model.CursorCharIdx + 1) % $script:CURSOR_CHARS.Count }
                Cmd   = $null
            }
        }

        'Input:*' {
            $typedChar = $msg.Substring(6)   # strip 'Input:' prefix
            $val    = [string]$model.InputValue
            $curPos = [math]::Max(0, [math]::Min($model.InputCursor, $val.Length))
            $newVal = $val.Substring(0, $curPos) + $typedChar + $val.Substring($curPos)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputValue = $newVal; InputCursor = $curPos + 1 }
                Cmd   = $null
            }
        }

        # --- textarea ---
        'TextareaUp' {
            $newRow  = [math]::Max($model.TextareaRow - 1, 0)
            $newLine = [string]$model.TextareaLines[$newRow]
            $newCol  = [math]::Min($model.TextareaCol, $newLine.Length)
            $maxVis  = $script:TA_MAX_VIS[$model.TextareaMaxVisIdx]
            $newOff  = $model.TextareaOffset
            if ($newRow -lt $newOff) { $newOff = $newRow }
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaRow = $newRow; TextareaCol = $newCol; TextareaOffset = $newOff }
                Cmd   = $null
            }
        }
        'TextareaDown' {
            $maxRow  = $model.TextareaLines.Count - 1
            $newRow  = [math]::Min($model.TextareaRow + 1, $maxRow)
            $newLine = [string]$model.TextareaLines[$newRow]
            $newCol  = [math]::Min($model.TextareaCol, $newLine.Length)
            $maxVis  = $script:TA_MAX_VIS[$model.TextareaMaxVisIdx]
            $newOff  = $model.TextareaOffset
            if ($newRow -ge $newOff + $maxVis) { $newOff = $newRow - $maxVis + 1 }
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaRow = $newRow; TextareaCol = $newCol; TextareaOffset = $newOff }
                Cmd   = $null
            }
        }
        'TextareaLeft' {
            $newCol = [math]::Max($model.TextareaCol - 1, 0)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaCol = $newCol }
                Cmd   = $null
            }
        }
        'TextareaRight' {
            $line   = [string]$model.TextareaLines[$model.TextareaRow]
            $newCol = [math]::Min($model.TextareaCol + 1, $line.Length)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaCol = $newCol }
                Cmd   = $null
            }
        }
        'TextareaBackspace' {
            $lines  = [System.Collections.Generic.List[string]]::new([string[]]$model.TextareaLines)
            $row    = [math]::Max(0, [math]::Min($model.TextareaRow, $lines.Count - 1))
            $line   = $lines[$row]
            $col    = [math]::Max(0, [math]::Min($model.TextareaCol, $line.Length))
            if ($col -gt 0) {
                $lines[$row] = $line.Substring(0, $col - 1) + $line.Substring($col)
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ TextareaLines = $lines.ToArray(); TextareaCol = $col - 1 }
                    Cmd   = $null
                }
            } elseif ($row -gt 0) {
                $prevLine    = $lines[$row - 1]
                $newCol      = $prevLine.Length
                $lines[$row - 1] = $prevLine + $line
                $lines.RemoveAt($row)
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ TextareaLines = $lines.ToArray(); TextareaRow = $row - 1; TextareaCol = $newCol }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        'TextareaEnter' {
            $lines  = [System.Collections.Generic.List[string]]::new([string[]]$model.TextareaLines)
            $row    = [math]::Max(0, [math]::Min($model.TextareaRow, $lines.Count - 1))
            $line   = $lines[$row]
            $col    = [math]::Max(0, [math]::Min($model.TextareaCol, $line.Length))
            $lines[$row] = $line.Substring(0, $col)
            $lines.Insert($row + 1, $line.Substring($col))
            $maxVis = $script:TA_MAX_VIS[$model.TextareaMaxVisIdx]
            $newRow = $row + 1
            $newOff = $model.TextareaOffset
            if ($newRow -ge $newOff + $maxVis) { $newOff = $newRow - $maxVis + 1 }
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaLines = $lines.ToArray(); TextareaRow = $newRow; TextareaCol = 0; TextareaOffset = $newOff }
                Cmd   = $null
            }
        }
        'TextareaFocusToggle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaFocused = (-not $model.TextareaFocused) }
                Cmd   = $null
            }
        }
        'TextareaCursorCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaCursorIdx = ($model.TextareaCursorIdx + 1) % $script:CURSOR_CHARS.Count }
                Cmd   = $null
            }
        }
        'TextareaMaxVisCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaMaxVisIdx = ($model.TextareaMaxVisIdx + 1) % $script:TA_MAX_VIS.Count }
                Cmd   = $null
            }
        }
        'TextareaInput:*' {
            $typedChar = $msg.Substring(14)   # strip 'TextareaInput:' prefix (14 chars)
            $lines  = [System.Collections.Generic.List[string]]::new([string[]]$model.TextareaLines)
            $row    = [math]::Max(0, [math]::Min($model.TextareaRow, $lines.Count - 1))
            $line   = $lines[$row]
            $col    = [math]::Max(0, [math]::Min($model.TextareaCol, $line.Length))
            $lines[$row] = $line.Substring(0, $col) + $typedChar + $line.Substring($col)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TextareaLines = $lines.ToArray(); TextareaCol = $col + 1 }
                Cmd   = $null
            }
        }

        # --- table ---
        'TableUp' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TableCursor = [math]::Max($model.TableCursor - 1, 0) }
                Cmd   = $null
            }
        }
        'TableDown' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ TableCursor = [math]::Min($model.TableCursor + 1, $script:TABLE_ROWS.Count - 1) }
                Cmd   = $null
            }
        }

        # --- paginator ---
        'PagerLeft' {
            if ($model.PagerModeIdx -eq 1) {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerTabIdx = [math]::Max($model.PagerTabIdx - 1, 0) }
                    Cmd   = $null
                }
            } else {
                # Numeric (0) and Dots (2) both navigate page
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerPage = [math]::Max($model.PagerPage - 1, 1) }
                    Cmd   = $null
                }
            }
        }
        'PagerRight' {
            if ($model.PagerModeIdx -eq 1) {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerTabIdx = [math]::Min($model.PagerTabIdx + 1, $script:PAGER_TAB_LABELS.Count - 1) }
                    Cmd   = $null
                }
            } else {
                # Numeric (0) and Dots (2) both navigate page
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerPage = [math]::Min($model.PagerPage + 1, $script:PAGER_PAGES) }
                    Cmd   = $null
                }
            }
        }
        'PagerModeCycle' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ PagerModeIdx = ($model.PagerModeIdx + 1) % $script:PAGER_MODES.Count }
                Cmd   = $null
            }
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

    # Shared styles
    $titleStyle    = New-ElmStyle -Foreground 'BrightCyan'  -Bold
    $hintStyle     = New-ElmStyle -Foreground 'BrightBlack'
    $activeTab     = New-ElmStyle -Foreground 'BrightWhite' -Bold -Underline
    $inactiveTab   = New-ElmStyle -Foreground 'BrightBlack'
    $accentStyle   = New-ElmStyle -Foreground 'BrightYellow'
    $labelStyle    = New-ElmStyle -Foreground 'BrightWhite'
    $configStyle   = New-ElmStyle -Foreground 'BrightCyan'
    $inputStyle    = New-ElmStyle -Foreground 'White'
    $inputFocStyle = New-ElmStyle -Foreground 'Black' -Background 'White'
    $listStyle     = New-ElmStyle -Foreground 'White'
    $selStyle      = New-ElmStyle -Foreground 'BrightYellow' -Bold
    $vpStyle       = New-ElmStyle -Foreground 'BrightGreen'

    $tabNames = @('[1] Animate', '[2] List', '[3] Viewport', '[4] Input', '[5] Textarea', '[6] Table', '[7] Paginator')
    $tabRow   = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $tabNames.Count; $i++) {
        $ts = if ($i -eq $model.Tab) { $activeTab } else { $inactiveTab }
        $tabRow.Add((New-ElmText -Content "  $($tabNames[$i])  " -Style $ts))
    }

    $children = [System.Collections.Generic.List[object]]::new()
    $children.Add((New-ElmText -Content 'Elm Widget Showcase' -Style $titleStyle))
    $children.Add((New-ElmRow -Children $tabRow.ToArray()))
    $children.Add((New-ElmText -Content ('-' * 50) -Style $hintStyle))

    switch ($model.Tab) {
        0 {
            # ----- Animation: New-ElmSpinner + New-ElmProgressBar -----
            $barWidth   = $script:BAR_WIDTHS[$model.BarWidthIdx]
            $filledChar = $script:FILLED_CHARS[$model.FilledCharIdx]
            $emptyChar  = $script:EMPTY_CHARS[$model.EmptyCharIdx]

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmSpinner' -Style $labelStyle))
            $spinVariants = @('Dots', 'Braille', 'Bounce', 'Arrow')
            foreach ($variant in $spinVariants) {
                $spinNode = New-ElmSpinner -Frame $model.Frame -Variant $variant -Style $accentStyle
                $label    = New-ElmText -Content "  -Variant $($variant.PadRight(7)): " -Style $hintStyle
                $children.Add((New-ElmRow -Children @($label, $spinNode)))
            }

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmProgressBar' -Style $labelStyle))
            $pct     = [int]([math]::Round($model.Progress * 100))
            $barNode = New-ElmProgressBar -Value $model.Progress -Width $barWidth `
                                          -FilledChar $filledChar -EmptyChar $emptyChar `
                                          -Style $accentStyle
            $children.Add($barNode)
            $children.Add((New-ElmText -Content "  $pct%" -Style $hintStyle))

            $children.Add((New-ElmText -Content '' ))
            $emptyDisplay = if ($emptyChar -eq ' ') { 'spc' } else { $emptyChar }
            $widthOpts    = $script:BAR_WIDTHS -join '/'
            $filledOpts   = $script:FILLED_CHARS -join '/'
            $emptyOpts    = ($script:EMPTY_CHARS | ForEach-Object { if ($_ -eq ' ') { 'spc' } else { $_ } }) -join '/'
            $children.Add((New-ElmText -Content "  -Width $barWidth [W: $widthOpts]  -FilledChar '$filledChar' [F: $filledOpts]  -EmptyChar '$emptyDisplay' [E: $emptyOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content '[W] Width  [F] FilledChar  [E] EmptyChar  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        1 {
            # ----- List: New-ElmList -----
            $maxVis = $script:LIST_MAX_VIS[$model.ListMaxVisIdx]
            $prefix = $script:LIST_PREFIXES[$model.ListPrefixIdx]

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmList  —  ANSI Color Names' -Style $labelStyle))
            $listNode = New-ElmList -Items $script:COLOR_NAMES `
                                    -SelectedIndex $model.ListCursor `
                                    -MaxVisible $maxVis `
                                    -Prefix $prefix.Sel `
                                    -UnselectedPrefix $prefix.Unsel `
                                    -Style $listStyle `
                                    -SelectedStyle $selStyle
            $children.Add($listNode)

            $itemName   = $script:COLOR_NAMES[$model.ListCursor]
            $maxVisOpts = $script:LIST_MAX_VIS -join '/'
            $prefixOpts = ($script:LIST_PREFIXES | ForEach-Object { "'$($_.Sel)'" }) -join '/'
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Selected: $itemName  ($($model.ListCursor + 1)/$($script:COLOR_NAMES.Count))" -Style (New-ElmStyle -Foreground $itemName)))
            $children.Add((New-ElmText -Content "  -MaxVisible $maxVis [M: $maxVisOpts]  -Prefix '$($prefix.Sel)' [V: $prefixOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content '[Up/Down] navigate  [M] MaxVisible  [V] Prefix  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        2 {
            # ----- Viewport: New-ElmViewport -----
            $maxVis = $script:VP_MAX_VIS[$model.VpMaxVisIdx]

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmViewport  —  Widget Documentation' -Style $labelStyle))
            $vpNode = New-ElmViewport -Lines $script:VIEWPORT_LINES `
                                      -ScrollOffset $model.ViewOffset `
                                      -MaxVisible $maxVis `
                                      -Style $vpStyle
            $children.Add($vpNode)

            $maxOff     = [math]::Max(0, $script:VIEWPORT_LINES.Count - $maxVis)
            $maxVisOpts = $script:VP_MAX_VIS -join '/'
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Line $($model.ViewOffset + 1)/$($script:VIEWPORT_LINES.Count)  (scroll range: 0-$maxOff)" -Style $hintStyle))
            $children.Add((New-ElmText -Content "  -MaxVisible $maxVis [M: $maxVisOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content '[Up/Down] scroll  [M] MaxVisible  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        3 {
            # ----- TextInput: New-ElmTextInput -----
            $cursorChar = $script:CURSOR_CHARS[$model.CursorCharIdx]
            $isFocused  = $model.InputFocused

            $focusedBoxStyle = New-ElmStyle -Border 'Rounded'
            $tiParams = @{
                Value           = $model.InputValue
                CursorPos       = $model.InputCursor
                Placeholder     = 'Press F to focus here!'
                CursorChar      = $cursorChar
                Style           = $inputStyle
                FocusedStyle    = $inputFocStyle
                FocusedBoxStyle = $focusedBoxStyle
            }
            $tiNode = if ($isFocused) { New-ElmTextInput @tiParams -Focused } else { New-ElmTextInput @tiParams }

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmTextInput' -Style $labelStyle))
            $label = New-ElmText -Content '  > ' -Style $hintStyle
            $children.Add((New-ElmRow -Children @($label, $tiNode)))

            $val        = [string]$model.InputValue
            $focusedStr = if ($isFocused) { 'on' } else { 'off' }
            $cursorOpts = $script:CURSOR_CHARS -join '/'
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Length: $($val.Length)  Cursor: $($model.InputCursor)" -Style $hintStyle))
            $children.Add((New-ElmText -Content "  -Focused $focusedStr [F: on/off]  -CursorChar '$cursorChar' [C: $cursorOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '  -FocusedStyle (Black/White bg)  -FocusedBoxStyle (Rounded border)' -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            if ($isFocused) {
                $children.Add((New-ElmText -Content '[type] input  [Left/Right] cursor  [Backspace] delete  [Esc] unfocus to quit' -Style $hintStyle))
            } else {
                $children.Add((New-ElmText -Content '[F] Focused  [C] CursorChar  [Left/Right] cursor  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
            }
        }

        4 {
            # ----- Textarea: New-ElmTextarea -----
            $cursorChar = $script:CURSOR_CHARS[$model.TextareaCursorIdx]
            $maxVis     = $script:TA_MAX_VIS[$model.TextareaMaxVisIdx]
            $isFocused  = $model.TextareaFocused

            $focusedBoxStyle = New-ElmStyle -Border 'Rounded'
            $taParams = @{
                Lines           = $model.TextareaLines
                CursorRow       = $model.TextareaRow
                CursorCol       = $model.TextareaCol
                MaxVisible      = $maxVis
                ScrollOffset    = $model.TextareaOffset
                Placeholder     = 'Press F to focus here!'
                CursorChar      = $cursorChar
                Style           = $inputStyle
                FocusedStyle    = $inputFocStyle
                FocusedBoxStyle = $focusedBoxStyle
            }
            $taNode = if ($isFocused) { New-ElmTextarea @taParams -Focused } else { New-ElmTextarea @taParams }

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmTextarea  —  Multi-line editor' -Style $labelStyle))
            $children.Add($taNode)

            $focusedStr = if ($isFocused) { 'on' } else { 'off' }
            $taMaxOpts  = $script:TA_MAX_VIS -join '/'
            $cursorOpts = $script:CURSOR_CHARS -join '/'
            $lineCount  = $model.TextareaLines.Count
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Row: $($model.TextareaRow + 1)/$lineCount  Col: $($model.TextareaCol)" -Style $hintStyle))
            $children.Add((New-ElmText -Content "  -Focused $focusedStr [F]  -MaxVisible $maxVis [M: $taMaxOpts]  -CursorChar '$cursorChar' [C: $cursorOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '  -FocusedStyle (Black/White bg)  -FocusedBoxStyle (Rounded border)' -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            if ($isFocused) {
                $children.Add((New-ElmText -Content '[type] input  [Enter] new line  [Backspace] delete  [Arrow keys] navigate  [Esc] unfocus' -Style $hintStyle))
            } else {
                $children.Add((New-ElmText -Content '[F] Focus  [M] MaxVisible  [C] CursorChar  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
            }
        }

        5 {
            # ----- Table: New-ElmTable -----
            $headerStyle  = New-ElmStyle -Foreground 'BrightCyan' -Bold
            $tableSelStyle = New-ElmStyle -Foreground 'BrightYellow' -Bold

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmTable  —  Widget Reference' -Style $labelStyle))
            $tableNode = New-ElmTable -Headers $script:TABLE_HEADERS `
                                      -Rows    $script:TABLE_ROWS `
                                      -SelectedRow  $model.TableCursor `
                                      -Style        $listStyle `
                                      -HeaderStyle  $headerStyle `
                                      -SelectedStyle $tableSelStyle
            $children.Add($tableNode)

            $selected = $script:TABLE_ROWS[$model.TableCursor]
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Row $($model.TableCursor + 1)/$($script:TABLE_ROWS.Count)  —  $($selected[0])" -Style $hintStyle))
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content '[Up/Down] select row  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        6 {
            # ----- Paginator: New-ElmPaginator -----
            $pagerMode    = $script:PAGER_MODES[$model.PagerModeIdx]
            $numericStyle = New-ElmStyle -Foreground 'BrightMagenta'
            $tabStyle     = New-ElmStyle -Foreground 'BrightBlack'
            $activeTabStyle = New-ElmStyle -Foreground 'BrightWhite' -Bold

            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content 'New-ElmPaginator  —  Navigation widgets' -Style $labelStyle))
            $children.Add((New-ElmText -Content '' ))

            $dotStyle     = New-ElmStyle -Foreground 'BrightMagenta'
            $activeDotStyle = New-ElmStyle -Foreground 'BrightWhite' -Bold

            # Numeric mode row
            $numNode = New-ElmPaginator -CurrentPage $model.PagerPage -PageCount $script:PAGER_PAGES -Style $numericStyle
            $label   = New-ElmText -Content '  Numeric:  ' -Style $hintStyle
            $arrow   = if ($pagerMode -eq 'Numeric') { New-ElmText -Content '>> ' -Style $accentStyle } else { New-ElmText -Content '   ' }
            $children.Add((New-ElmRow -Children @($arrow, $label, $numNode)))

            # Dots mode row
            $dotsNode = New-ElmPaginator -Dots -CurrentPage $model.PagerPage -PageCount $script:PAGER_PAGES `
                                         -Style $dotStyle -ActiveStyle $activeDotStyle
            $label3   = New-ElmText -Content '  Dots:     ' -Style $hintStyle
            $arrow3   = if ($pagerMode -eq 'Dots') { New-ElmText -Content '>> ' -Style $accentStyle } else { New-ElmText -Content '   ' }
            $children.Add((New-ElmRow -Children @($arrow3, $label3, $dotsNode)))

            # Tabs mode row
            $tabNode = New-ElmPaginator -Tabs $script:PAGER_TAB_LABELS -ActiveTab $model.PagerTabIdx `
                                        -Style $tabStyle -ActiveStyle $activeTabStyle
            $label2  = New-ElmText -Content '  Tabs:     ' -Style $hintStyle
            $arrow2  = if ($pagerMode -eq 'Tabs') { New-ElmText -Content '>> ' -Style $accentStyle } else { New-ElmText -Content '   ' }
            $children.Add((New-ElmRow -Children @($arrow2, $label2, $tabNode)))

            $modeOpts = $script:PAGER_MODES -join '/'
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content "  Active mode: $pagerMode [M: $modeOpts]" -Style $configStyle))
            $children.Add((New-ElmText -Content '' ))
            $children.Add((New-ElmText -Content '[Left/Right] navigate  [M] Mode  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }
    }

    New-ElmBox -Children $children.ToArray()
}

$subFn = {
    param($model)
    $subs = [System.Collections.Generic.List[object]]::new()

    # Suppress Q/N/P when a text widget is focused so those chars can be typed
    $textFocused = ($model.Tab -eq 3 -and $model.InputFocused) -or ($model.Tab -eq 4 -and $model.TextareaFocused)
    if (-not $textFocused) {
        $subs.Add((New-ElmKeySub -Key 'Q' -Handler { 'Quit'    }))
        $subs.Add((New-ElmKeySub -Key 'N' -Handler { 'TabNext' }))
        $subs.Add((New-ElmKeySub -Key 'P' -Handler { 'TabPrev' }))
    }

    # Timer — always runs (spinner animation + progress auto-advance)
    $subs.Add((New-ElmTimerSub -IntervalMs 120 -Handler { 'Tick' }))

    # Panel-specific keys
    switch ($model.Tab) {
        0 {
            $subs.Add((New-ElmKeySub -Key 'W' -Handler { 'BarWidthCycle'   }))
            $subs.Add((New-ElmKeySub -Key 'F' -Handler { 'FilledCharCycle' }))
            $subs.Add((New-ElmKeySub -Key 'E' -Handler { 'EmptyCharCycle'  }))
        }
        1 {
            $subs.Add((New-ElmKeySub -Key 'UpArrow'   -Handler { 'ListUp'          }))
            $subs.Add((New-ElmKeySub -Key 'DownArrow' -Handler { 'ListDown'        }))
            $subs.Add((New-ElmKeySub -Key 'M'         -Handler { 'ListMaxVisCycle' }))
            $subs.Add((New-ElmKeySub -Key 'V'         -Handler { 'ListPrefixCycle' }))
        }
        2 {
            $subs.Add((New-ElmKeySub -Key 'UpArrow'   -Handler { 'ViewUp'        }))
            $subs.Add((New-ElmKeySub -Key 'DownArrow' -Handler { 'ViewDown'      }))
            $subs.Add((New-ElmKeySub -Key 'M'         -Handler { 'VpMaxVisCycle' }))
        }
        3 {
            $subs.Add((New-ElmKeySub -Key 'LeftArrow'  -Handler { 'InputLeft'  }))
            $subs.Add((New-ElmKeySub -Key 'RightArrow' -Handler { 'InputRight' }))
            $subs.Add((New-ElmKeySub -Key 'Backspace'  -Handler { 'Backspace'  }))
            if ($model.InputFocused) {
                # Focused: char sub captures all printable input; Esc unfocuses
                $subs.Add((New-ElmKeySub -Key 'Escape' -Handler { 'InputToggleFocus' }))
                $subs.Add((New-ElmCharSub -Handler { param($e) "Input:$([string]$e.Char)" }))
            } else {
                # Unfocused: expose config keys
                $subs.Add((New-ElmKeySub -Key 'F' -Handler { 'InputToggleFocus' }))
                $subs.Add((New-ElmKeySub -Key 'C' -Handler { 'CursorCharCycle'  }))
            }
        }
        4 {
            $subs.Add((New-ElmKeySub -Key 'UpArrow'   -Handler { 'TextareaUp'    }))
            $subs.Add((New-ElmKeySub -Key 'DownArrow' -Handler { 'TextareaDown'  }))
            $subs.Add((New-ElmKeySub -Key 'LeftArrow' -Handler { 'TextareaLeft'  }))
            $subs.Add((New-ElmKeySub -Key 'RightArrow'-Handler { 'TextareaRight' }))
            $subs.Add((New-ElmKeySub -Key 'Backspace' -Handler { 'TextareaBackspace' }))
            if ($model.TextareaFocused) {
                $subs.Add((New-ElmKeySub -Key 'Enter'  -Handler { 'TextareaEnter'       }))
                $subs.Add((New-ElmKeySub -Key 'Escape' -Handler { 'TextareaFocusToggle' }))
                $subs.Add((New-ElmCharSub -Handler { param($e) "TextareaInput:$([string]$e.Char)" }))
            } else {
                $subs.Add((New-ElmKeySub -Key 'F' -Handler { 'TextareaFocusToggle' }))
                $subs.Add((New-ElmKeySub -Key 'M' -Handler { 'TextareaMaxVisCycle' }))
                $subs.Add((New-ElmKeySub -Key 'C' -Handler { 'TextareaCursorCycle' }))
            }
        }
        5 {
            $subs.Add((New-ElmKeySub -Key 'UpArrow'   -Handler { 'TableUp'   }))
            $subs.Add((New-ElmKeySub -Key 'DownArrow' -Handler { 'TableDown' }))
        }
        6 {
            $subs.Add((New-ElmKeySub -Key 'LeftArrow'  -Handler { 'PagerLeft'      }))
            $subs.Add((New-ElmKeySub -Key 'RightArrow' -Handler { 'PagerRight'     }))
            $subs.Add((New-ElmKeySub -Key 'M'          -Handler { 'PagerModeCycle' }))
        }
    }

    return $subs.ToArray()
}

function Invoke-WidgetShowcaseDemo {
    <#
    .SYNOPSIS
        Interactive showcase of the Elm Phase 9 widget library.

    .DESCRIPTION
        Cycles through four panels demonstrating all five Phase 9 widgets
        with live-adjustable configuration options.

        Global keys:
          P / N      — previous / next panel
          Q          — quit

        Panel 1 — Animation:   W / F / E  cycle Width / FilledChar / EmptyChar
        Panel 2 — List:        Up/Down navigate  M / V  cycle MaxVisible / Prefix
        Panel 3 — Viewport:    Up/Down scroll    M  cycle MaxVisible
        Panel 4 — TextInput:   Left/Right cursor  Backspace delete  F / C  Focused / CursorChar

    .NOTES
        Requires the Elm module.
        Run from Examples: . .\Invoke-WidgetShowcaseDemo.ps1; Invoke-WidgetShowcaseDemo
    #>
    [CmdletBinding()]
    param()

    Start-ElmProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn -SubscriptionFn $subFn
}

Invoke-WidgetShowcaseDemo

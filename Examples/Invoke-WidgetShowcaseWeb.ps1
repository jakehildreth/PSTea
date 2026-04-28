Import-Module "$PSScriptRoot/../PSTea.psd1" -Force

# ---------------------------------------------------------------------------
# Widget Showcase - Web version
# Same app as Invoke-WidgetShowcaseDemo.ps1 served in the browser via xterm.js.
# Run: ./Examples/Invoke-WidgetShowcaseWeb.ps1
# Then open: http://localhost:8080
# ---------------------------------------------------------------------------

$script:PANEL_COUNT = 7

$script:BAR_WIDTHS    = @(20, 30, 40)
$script:FILLED_CHARS  = @([char]0x2588, '#', '=', '*', '+')
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
$script:TA_MAX_VIS    = @(4, 8, 12, 16)
$script:PAGER_MODES   = @('Numeric', 'Tabs', 'Dots')
$script:PAGER_PAGES   = 7
$script:PAGER_TAB_LABELS = @('Animate','List','Viewport','Input','Textarea','Table','Paginator')

$script:TABLE_HEADERS = @('Widget', 'Returns', 'Key Params')
$script:TABLE_ROWS    = @(
    ,@('New-TeaProgressBar', 'Text',        '-Value/-Percent, -Width')
    ,@('New-TeaSpinner',     'Text',        '-Frame, -Variant')
    ,@('New-TeaList',        'Box/Vertical','-Items, -SelectedIndex')
    ,@('New-TeaViewport',    'Box/Vertical','-Lines, -ScrollOffset')
    ,@('New-TeaTextInput',   'Text/Box',    '-Value, -CursorPos, -FocusedStyle, -FocusedBoxStyle')
    ,@('New-TeaTextarea',    'Box/Vertical','-Lines, -CursorRow/-Col, -FocusedStyle, -FocusedBoxStyle')
    ,@('New-TeaTable',       'Box/Vertical','-Headers, -Rows')
    ,@('New-TeaPaginator',   'Text/Box',    '-CurrentPage / -Tabs / -Dots')
)

$script:VIEWPORT_LINES = @(
    'Phase 9 Widget Library - PSTea'
    '============================================'
    ''
    'New-TeaProgressBar'
    '  Horizontal progress bar.'
    '  -Value 0.0..1.0 or -Percent 0..100'
    '  -Width (min 4), -FilledChar, -EmptyChar'
    '  Returns a Text node: [###-------]'
    ''
    'New-TeaSpinner'
    '  Animated spinner driven by a frame counter.'
    '  -Frame (caller increments), -Variant:'
    '    Dots   |  /  -  \  (default)'
    '    Braille  10 braille chars'
    '    Bounce  .  o  O  o'
    '    Arrow   >  >>  >>>'
    '  -Frames for a fully custom sequence.'
    ''
    'New-TeaList'
    '  Scrollable, selectable list of strings.'
    '  -Items, -SelectedIndex, -MaxVisible'
    '  -Prefix (selected), -UnselectedPrefix'
    '  -Style, -SelectedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-TeaViewport'
    '  Fixed-height window into a string array.'
    '  -Lines, -ScrollOffset, -MaxVisible, -Style'
    '  Clamps scroll offset automatically.'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-TeaTextInput'
    '  Single-line text input with cursor.'
    '  -Value, -CursorPos, -Focused (switch)'
    '  -Placeholder shown when empty+unfocused.'
    '  -CursorChar (default |)'
    '  -Style, -FocusedStyle'
    '  Returns a Text node.'
    ''
    'New-TeaTextarea'
    '  Multi-line text area with cursor.'
    '  -Lines [string[]], -CursorRow, -CursorCol'
    '  -Focused (switch), -MaxVisible, -ScrollOffset'
    '  -Placeholder, -CursorChar, -Style, -FocusedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-TeaTable'
    '  Data table with optional headers and row selection.'
    '  -Headers [string[]], -Rows [object[]]'
    '  -SelectedRow (-1 = no selection), -ColumnWidths'
    '  -Style, -HeaderStyle, -SelectedStyle'
    '  Returns a Box (Vertical) of Text nodes.'
    ''
    'New-TeaPaginator'
    '  Numeric page indicator or named tab bar.'
    '  Numeric: -CurrentPage, -PageCount'
    '    renders: < 3 / 7 >'
    '  Tabs:    -Tabs [string[]], -ActiveTab'
    '    renders: Tab1 | [Tab2] | Tab3'
    '  -Style, -ActiveStyle'
    '  Returns Text (Numeric) or Box/Horizontal (Tabs).'
)

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
        TextareaLines     = $Model.TextareaLines
        TextareaRow       = $Model.TextareaRow
        TextareaCol       = $Model.TextareaCol
        TextareaOffset    = $Model.TextareaOffset
        TextareaFocused   = $Model.TextareaFocused
        TextareaCursorIdx = $Model.TextareaCursorIdx
        TextareaMaxVisIdx = $Model.TextareaMaxVisIdx
        TableCursor       = $Model.TableCursor
        PagerPage         = $Model.PagerPage
        PagerDotsPage     = $Model.PagerDotsPage
        PagerTabIdx       = $Model.PagerTabIdx
        PagerModeIdx      = $Model.PagerModeIdx
    }
    foreach ($key in $Overrides.Keys) { $m.$key = $Overrides[$key] }
    $m
}

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Tab           = 0
            Frame         = 0
            Progress      = 0.0
            ListCursor    = 0
            ViewOffset    = 0
            InputValue    = ''
            InputCursor   = 0
            InputFocused  = $false
            BarWidthIdx   = 1
            FilledCharIdx = 0
            EmptyCharIdx  = 0
            ListMaxVisIdx = 2
            ListPrefixIdx = 0
            VpMaxVisIdx   = 2
            CursorCharIdx = 0
            TextareaLines     = [string[]]@('')
            TextareaRow       = 0
            TextareaCol       = 0
            TextareaOffset    = 0
            TextareaFocused   = $false
            TextareaCursorIdx = 0
            TextareaMaxVisIdx = 1
            TableCursor       = 0
            PagerPage         = 1
            PagerDotsPage     = 1
            PagerTabIdx       = 0
            PagerModeIdx      = 0
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
        'TabJump:*' {
            $idx = [int]$msg.Substring(8)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ Tab = [math]::Max(0, [math]::Min($idx, $script:PANEL_COUNT - 1)) }
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
            $typedChar = $msg.Substring(6)
            $val    = [string]$model.InputValue
            $curPos = [math]::Max(0, [math]::Min($model.InputCursor, $val.Length))
            $newVal = $val.Substring(0, $curPos) + $typedChar + $val.Substring($curPos)
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ InputValue = $newVal; InputCursor = $curPos + 1 }
                Cmd   = $null
            }
        }
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
            $typedChar = $msg.Substring(14)
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
        'PagerLeft' {
            if ($model.PagerModeIdx -eq 1) {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerTabIdx = [math]::Max($model.PagerTabIdx - 1, 0) }
                    Cmd   = $null
                }
            } elseif ($model.PagerModeIdx -eq 2) {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerDotsPage = [math]::Max($model.PagerDotsPage - 1, 1) }
                    Cmd   = $null
                }
            } else {
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
            } elseif ($model.PagerModeIdx -eq 2) {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerDotsPage = [math]::Min($model.PagerDotsPage + 1, $script:PAGER_PAGES) }
                    Cmd   = $null
                }
            } else {
                return [PSCustomObject]@{
                    Model = New-ShowcaseModel $model @{ PagerPage = [math]::Min($model.PagerPage + 1, $script:PAGER_PAGES) }
                    Cmd   = $null
                }
            }
        }
        'PagerModeNext' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ PagerModeIdx = ($model.PagerModeIdx + 1) % $script:PAGER_MODES.Count }
                Cmd   = $null
            }
        }
        'PagerModePrev' {
            return [PSCustomObject]@{
                Model = New-ShowcaseModel $model @{ PagerModeIdx = ($model.PagerModeIdx + $script:PAGER_MODES.Count - 1) % $script:PAGER_MODES.Count }
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

    $titleStyle    = New-TeaStyle -Foreground 'BrightCyan'  -Bold
    $hintStyle     = New-TeaStyle -Foreground 'BrightBlack'
    $activeTab     = New-TeaStyle -Foreground 'BrightWhite' -Bold
    $inactiveTab   = New-TeaStyle -Foreground 'BrightBlack'
    $accentStyle   = New-TeaStyle -Foreground 'BrightYellow'
    $labelStyle    = New-TeaStyle -Foreground 'BrightWhite'
    $configStyle   = New-TeaStyle -Foreground 'BrightCyan'
    $inputStyle    = New-TeaStyle -Foreground 'White'
    $inputFocStyle = New-TeaStyle -Foreground 'Black' -Background 'White'
    $listStyle     = New-TeaStyle -Foreground 'White'
    $selStyle      = New-TeaStyle -Foreground 'BrightYellow' -Bold
    $vpStyle       = New-TeaStyle -Foreground 'BrightGreen'

    $tabNames  = @('[1] Animate', '[2] List', '[3] Viewport', '[4] Input', '[5] Textarea', '[6] Table', '[7] Paginator')
    $tabWidth  = ($tabNames | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $tabRow1   = [System.Collections.Generic.List[object]]::new()
    $tabRow2   = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $tabNames.Count; $i++) {
        $ts     = if ($i -eq $model.Tab) { $activeTab } else { $inactiveTab }
        $padded = $tabNames[$i].PadRight($tabWidth)
        $node   = New-TeaText -Content "  $padded  " -Style $ts
        if ($i -lt 4) { $tabRow1.Add($node) } else { $tabRow2.Add($node) }
    }

    $children = [System.Collections.Generic.List[object]]::new()
    $children.Add((New-TeaText -Content 'PSTea Widget Showcase' -Style $titleStyle))
    $children.Add((New-TeaText -Content ''))
    $children.Add((New-TeaRow -Children $tabRow1.ToArray()))
    $children.Add((New-TeaRow -Children $tabRow2.ToArray()))

    switch ($model.Tab) {
        0 {
            $barWidth   = $script:BAR_WIDTHS[$model.BarWidthIdx]
            $filledChar = $script:FILLED_CHARS[$model.FilledCharIdx]
            $emptyChar  = $script:EMPTY_CHARS[$model.EmptyCharIdx]

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaSpinner' -Style $labelStyle))
            $spinVariants = @('Dots', 'Braille', 'Bounce', 'Arrow')
            foreach ($variant in $spinVariants) {
                $spinNode = New-TeaSpinner -Frame $model.Frame -Variant $variant -Style $accentStyle
                $label    = New-TeaText -Content "  -Variant $($variant.PadRight(7)): " -Style $hintStyle
                $children.Add((New-TeaRow -Children @($label, $spinNode)))
            }

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaProgressBar' -Style $labelStyle))
            $pct     = [int]([math]::Round($model.Progress * 100))
            $barParams = @{
                Value      = $model.Progress
                Width      = $barWidth
                FilledChar = $filledChar
                EmptyChar  = $emptyChar
                Style      = $accentStyle
            }
            $barNode = New-TeaProgressBar @barParams
            $children.Add($barNode)
            $children.Add((New-TeaText -Content "  $pct%" -Style $hintStyle))

            $children.Add((New-TeaText -Content ''))
            $emptyDisplay = if ($emptyChar -eq ' ') { 'spc' } else { $emptyChar }
            $children.Add((New-TeaText -Content "  -Width $barWidth  -FilledChar '$filledChar'  -EmptyChar '$emptyDisplay'" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content '[W] Width  [F] FilledChar  [E] EmptyChar  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        1 {
            $maxVis = $script:LIST_MAX_VIS[$model.ListMaxVisIdx]
            $prefix = $script:LIST_PREFIXES[$model.ListPrefixIdx]

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaList  -  ANSI Color Names' -Style $labelStyle))
            $listParams = @{
                Items            = $script:COLOR_NAMES
                SelectedIndex    = $model.ListCursor
                MaxVisible       = $maxVis
                Prefix           = $prefix.Sel
                UnselectedPrefix = $prefix.Unsel
                Style            = $listStyle
                SelectedStyle    = $selStyle
            }
            $listNode = New-TeaList @listParams
            $children.Add($listNode)

            $itemName   = $script:COLOR_NAMES[$model.ListCursor]
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Selected: $itemName  ($($model.ListCursor + 1)/$($script:COLOR_NAMES.Count))" -Style (New-TeaStyle -Foreground $itemName)))
            $children.Add((New-TeaText -Content "  -MaxVisible $maxVis  -Prefix '$($prefix.Sel)'" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content '[Up/Down] navigate  [M] MaxVisible  [V] Prefix  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        2 {
            $maxVis = $script:VP_MAX_VIS[$model.VpMaxVisIdx]

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaViewport  -  Widget Documentation' -Style $labelStyle))
            $vpParams = @{
                Lines        = $script:VIEWPORT_LINES
                ScrollOffset = $model.ViewOffset
                MaxVisible   = $maxVis
                Style        = $vpStyle
            }
            $vpNode = New-TeaViewport @vpParams
            $children.Add($vpNode)

            $maxOff = [math]::Max(0, $script:VIEWPORT_LINES.Count - $maxVis)
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Line $($model.ViewOffset + 1)/$($script:VIEWPORT_LINES.Count)  (scroll range: 0-$maxOff)" -Style $hintStyle))
            $children.Add((New-TeaText -Content "  -MaxVisible $maxVis" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content '[Up/Down] scroll  [M] MaxVisible  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        3 {
            $cursorChar = $script:CURSOR_CHARS[$model.CursorCharIdx]
            $isFocused  = $model.InputFocused

            $focusedBoxStyle = New-TeaStyle -Border 'Rounded'
            $tiParams = @{
                Value           = $model.InputValue
                CursorPos       = $model.InputCursor
                Placeholder     = 'Press F to focus here!'
                CursorChar      = $cursorChar
                Style           = $inputStyle
                FocusedStyle    = $inputFocStyle
                FocusedBoxStyle = $focusedBoxStyle
            }
            $tiNode = if ($isFocused) { New-TeaTextInput @tiParams -Focused } else { New-TeaTextInput @tiParams }

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaTextInput' -Style $labelStyle))
            $label = New-TeaText -Content '  > ' -Style $hintStyle
            $children.Add((New-TeaRow -Children @($label, $tiNode)))

            $val        = [string]$model.InputValue
            $focusedStr = if ($isFocused) { 'on' } else { 'off' }
            $cursorOpts = $script:CURSOR_CHARS -join '/'
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Length: $($val.Length)  Cursor: $($model.InputCursor)" -Style $hintStyle))
            $children.Add((New-TeaText -Content "  -Focused $focusedStr [F: on/off]  -CursorChar '$cursorChar' [C: $cursorOpts]" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            if ($isFocused) {
                $children.Add((New-TeaText -Content '[type] input  [Left/Right] cursor  [Backspace] delete  [Esc] unfocus' -Style $hintStyle))
            } else {
                $children.Add((New-TeaText -Content '[F] Focused  [C] CursorChar  [Left/Right] cursor  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
            }
        }

        4 {
            $cursorChar = $script:CURSOR_CHARS[$model.TextareaCursorIdx]
            $maxVis     = $script:TA_MAX_VIS[$model.TextareaMaxVisIdx]
            $isFocused  = $model.TextareaFocused

            $focusedBoxStyle = New-TeaStyle -Border 'Rounded'
            $taParams = @{
                Lines           = $model.TextareaLines
                CursorRow       = $model.TextareaRow
                CursorCol       = $model.TextareaCol
                MaxVisible      = $maxVis
                ScrollOffset    = $model.TextareaOffset
                Placeholder     = 'Press F to focus, then type and press Enter!'
                CursorChar      = $cursorChar
                Style           = $inputStyle
                FocusedStyle    = $inputFocStyle
                FocusedBoxStyle = $focusedBoxStyle
            }
            $taNode = if ($isFocused) { New-TeaTextarea @taParams -Focused } else { New-TeaTextarea @taParams }

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaTextarea  -  Multi-line editor' -Style $labelStyle))
            $taLabel = New-TeaText -Content '  > ' -Style $hintStyle
            $children.Add((New-TeaRow -Children @($taLabel, $taNode)))

            $focusedStr = if ($isFocused) { 'on' } else { 'off' }
            $taMaxOpts  = $script:TA_MAX_VIS -join '/'
            $cursorOpts = $script:CURSOR_CHARS -join '/'
            $lineCount  = $model.TextareaLines.Count
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Row: $($model.TextareaRow + 1)/$lineCount  Col: $($model.TextareaCol)" -Style $hintStyle))
            $children.Add((New-TeaText -Content "  -Focused $focusedStr [F]  -MaxVisible $maxVis [M: $taMaxOpts]  -CursorChar '$cursorChar' [C: $cursorOpts]" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            if ($isFocused) {
                $children.Add((New-TeaText -Content '[type] input  [Enter] new line  [Backspace] delete  [Arrow keys] navigate  [Esc] unfocus' -Style $hintStyle))
            } else {
                $children.Add((New-TeaText -Content '[F] Focus  [M] MaxVisible  [C] CursorChar  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
            }
        }

        5 {
            $headerStyle   = New-TeaStyle -Foreground 'BrightCyan' -Bold
            $tableSelStyle = New-TeaStyle -Foreground 'BrightYellow' -Bold

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaTable  -  Widget Reference' -Style $labelStyle))
            $tableParams = @{
                Headers       = $script:TABLE_HEADERS
                Rows          = $script:TABLE_ROWS
                SelectedRow   = $model.TableCursor
                Style         = $listStyle
                HeaderStyle   = $headerStyle
                SelectedStyle = $tableSelStyle
            }
            $tableNode = New-TeaTable @tableParams
            $children.Add($tableNode)

            $selected = $script:TABLE_ROWS[$model.TableCursor]
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Row $($model.TableCursor + 1)/$($script:TABLE_ROWS.Count)  -  $($selected[0])" -Style $hintStyle))
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content '[Up/Down] select row  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }

        6 {
            $pagerMode      = $script:PAGER_MODES[$model.PagerModeIdx]
            $numericStyle   = New-TeaStyle -Foreground 'BrightMagenta'
            $tabStyle       = New-TeaStyle -Foreground 'BrightBlack'
            $activeTabStyle = New-TeaStyle -Foreground 'BrightWhite' -Bold
            $dotStyle       = New-TeaStyle -Foreground 'BrightMagenta'
            $activeDotStyle = New-TeaStyle -Foreground 'BrightWhite' -Bold

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content 'New-TeaPaginator  -  Navigation widgets' -Style $labelStyle))

            $numNode = New-TeaPaginator -CurrentPage $model.PagerPage -PageCount $script:PAGER_PAGES -Style $numericStyle
            $label   = New-TeaText -Content '  Numeric:  ' -Style $hintStyle
            $arrow   = if ($pagerMode -eq 'Numeric') { New-TeaText -Content '> ' -Style $accentStyle } else { New-TeaText -Content '  ' }
            $children.Add((New-TeaRow -Children @($arrow, $label, $numNode)))

            $dotsParams = @{
                Dots        = $true
                CurrentPage = $model.PagerDotsPage
                PageCount   = $script:PAGER_PAGES
                Style       = $dotStyle
                ActiveStyle = $activeDotStyle
            }
            $dotsNode = New-TeaPaginator @dotsParams
            $label3   = New-TeaText -Content '  Dots:     ' -Style $hintStyle
            $arrow3   = if ($pagerMode -eq 'Dots') { New-TeaText -Content '> ' -Style $accentStyle } else { New-TeaText -Content '  ' }
            $children.Add((New-TeaRow -Children @($arrow3, $label3, $dotsNode)))

            $tabParams = @{
                Tabs        = $script:PAGER_TAB_LABELS
                ActiveTab   = $model.PagerTabIdx
                Style       = $tabStyle
                ActiveStyle = $activeTabStyle
            }
            $tabNode = New-TeaPaginator @tabParams
            $label2  = New-TeaText -Content '  Tabs:     ' -Style $hintStyle
            $arrow2  = if ($pagerMode -eq 'Tabs') { New-TeaText -Content '> ' -Style $accentStyle } else { New-TeaText -Content '  ' }
            $children.Add((New-TeaRow -Children @($arrow2, $label2, $tabNode)))

            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content "  Active mode: $pagerMode" -Style $configStyle))
            $children.Add((New-TeaText -Content ''))
            $children.Add((New-TeaText -Content '[Left/Right] navigate  [Up/Down] Mode  [P] prev  [N] next  [Q] quit' -Style $hintStyle))
        }
    }

    New-TeaBox -Children $children.ToArray()
}

$subFn = {
    param($model)
    $subs = [System.Collections.Generic.List[object]]::new()

    $textFocused = ($model.Tab -eq 3 -and $model.InputFocused) -or ($model.Tab -eq 4 -and $model.TextareaFocused)
    if (-not $textFocused) {
        $subs.Add((New-TeaKeySub -Key 'Q' -Handler { 'Quit'    }))
        $subs.Add((New-TeaKeySub -Key 'N' -Handler { 'TabNext' }))
        $subs.Add((New-TeaKeySub -Key 'P' -Handler { 'TabPrev' }))
        $subs.Add((New-TeaKeySub -Key 'D1' -Handler { 'TabJump:0' }))
        $subs.Add((New-TeaKeySub -Key 'D2' -Handler { 'TabJump:1' }))
        $subs.Add((New-TeaKeySub -Key 'D3' -Handler { 'TabJump:2' }))
        $subs.Add((New-TeaKeySub -Key 'D4' -Handler { 'TabJump:3' }))
        $subs.Add((New-TeaKeySub -Key 'D5' -Handler { 'TabJump:4' }))
        $subs.Add((New-TeaKeySub -Key 'D6' -Handler { 'TabJump:5' }))
        $subs.Add((New-TeaKeySub -Key 'D7' -Handler { 'TabJump:6' }))
    }

    $subs.Add((New-TeaTimerSub -IntervalMs 120 -Handler { 'Tick' }))

    switch ($model.Tab) {
        0 {
            $subs.Add((New-TeaKeySub -Key 'W' -Handler { 'BarWidthCycle'   }))
            $subs.Add((New-TeaKeySub -Key 'F' -Handler { 'FilledCharCycle' }))
            $subs.Add((New-TeaKeySub -Key 'E' -Handler { 'EmptyCharCycle'  }))
        }
        1 {
            $subs.Add((New-TeaKeySub -Key 'UpArrow'   -Handler { 'ListUp'          }))
            $subs.Add((New-TeaKeySub -Key 'DownArrow' -Handler { 'ListDown'        }))
            $subs.Add((New-TeaKeySub -Key 'M'         -Handler { 'ListMaxVisCycle' }))
            $subs.Add((New-TeaKeySub -Key 'V'         -Handler { 'ListPrefixCycle' }))
        }
        2 {
            $subs.Add((New-TeaKeySub -Key 'UpArrow'   -Handler { 'ViewUp'        }))
            $subs.Add((New-TeaKeySub -Key 'DownArrow' -Handler { 'ViewDown'      }))
            $subs.Add((New-TeaKeySub -Key 'M'         -Handler { 'VpMaxVisCycle' }))
        }
        3 {
            $subs.Add((New-TeaKeySub -Key 'LeftArrow'  -Handler { 'InputLeft'  }))
            $subs.Add((New-TeaKeySub -Key 'RightArrow' -Handler { 'InputRight' }))
            $subs.Add((New-TeaKeySub -Key 'Backspace'  -Handler { 'Backspace'  }))
            if ($model.InputFocused) {
                $subs.Add((New-TeaKeySub -Key 'Escape' -Handler { 'InputToggleFocus' }))
                $subs.Add((New-TeaCharSub -Handler { param($e) "Input:$([string]$e.Char)" }))
            } else {
                $subs.Add((New-TeaKeySub -Key 'F' -Handler { 'InputToggleFocus' }))
                $subs.Add((New-TeaKeySub -Key 'C' -Handler { 'CursorCharCycle'  }))
            }
        }
        4 {
            $subs.Add((New-TeaKeySub -Key 'UpArrow'    -Handler { 'TextareaUp'    }))
            $subs.Add((New-TeaKeySub -Key 'DownArrow'  -Handler { 'TextareaDown'  }))
            $subs.Add((New-TeaKeySub -Key 'LeftArrow'  -Handler { 'TextareaLeft'  }))
            $subs.Add((New-TeaKeySub -Key 'RightArrow' -Handler { 'TextareaRight' }))
            $subs.Add((New-TeaKeySub -Key 'Backspace'  -Handler { 'TextareaBackspace' }))
            if ($model.TextareaFocused) {
                $subs.Add((New-TeaKeySub -Key 'Enter'  -Handler { 'TextareaEnter'       }))
                $subs.Add((New-TeaKeySub -Key 'Escape' -Handler { 'TextareaFocusToggle' }))
                $subs.Add((New-TeaCharSub -Handler { param($e) "TextareaInput:$([string]$e.Char)" }))
            } else {
                $subs.Add((New-TeaKeySub -Key 'F' -Handler { 'TextareaFocusToggle' }))
                $subs.Add((New-TeaKeySub -Key 'M' -Handler { 'TextareaMaxVisCycle' }))
                $subs.Add((New-TeaKeySub -Key 'C' -Handler { 'TextareaCursorCycle' }))
            }
        }
        5 {
            $subs.Add((New-TeaKeySub -Key 'UpArrow'   -Handler { 'TableUp'   }))
            $subs.Add((New-TeaKeySub -Key 'DownArrow' -Handler { 'TableDown' }))
        }
        6 {
            $subs.Add((New-TeaKeySub -Key 'LeftArrow'  -Handler { 'PagerLeft'     }))
            $subs.Add((New-TeaKeySub -Key 'RightArrow' -Handler { 'PagerRight'    }))
            $subs.Add((New-TeaKeySub -Key 'UpArrow'    -Handler { 'PagerModeNext' }))
            $subs.Add((New-TeaKeySub -Key 'DownArrow'  -Handler { 'PagerModePrev' }))
        }
    }

    return $subs.ToArray()
}

$serverParams = @{
    InitFn         = $initFn
    UpdateFn       = $updateFn
    ViewFn         = $viewFn
    SubscriptionFn = $subFn
    Port           = 8080
    Width          = 220
    Height         = 50
    Title          = 'PSTea Widget Showcase'
}
Start-TeaWebServer @serverParams

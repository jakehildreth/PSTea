function New-TeaTable {
    <#
    .SYNOPSIS
        Creates a data table view node.

    .DESCRIPTION
        Returns a Box (Vertical) view node rendering rows of tabular data with
        optional column headers and a selected-row highlight. Columns are padded
        to uniform widths and separated by ' | '. A separator row of dashes is
        rendered between the header and data rows when headers are present.

        Rendered example (3 columns):

            Name       | Age | City
            -----------+-----+----------
            Alice      | 30  | New York
          > Bob        | 25  | London

        Column widths are auto-calculated from the longest content in each column
        unless -ColumnWidths is supplied.

    .PARAMETER Headers
        Array of column header strings. When empty or omitted, no header row or
        separator row is rendered.

    .PARAMETER Rows
        Array of rows; each row is an array of strings (one per column). Required.

    .PARAMETER SelectedRow
        Zero-based index of the selected data row. -1 means no selection.
        Default: -1.

    .PARAMETER ColumnWidths
        Optional array of explicit column widths (one per column). When omitted,
        widths are calculated from the maximum content length in each column.

    .PARAMETER Style
        Tea style applied to all unselected data rows.

    .PARAMETER HeaderStyle
        Tea style applied to the header row and separator row.

    .PARAMETER SelectedStyle
        Tea style applied to the selected row. When omitted, defaults to bold.

    .OUTPUTS
        PSCustomObject - Box (Vertical) view node.

    .EXAMPLE
        New-TeaTable -Headers @('Name','Age','City') `
                     -Rows @(@('Alice','30','New York'),@('Bob','25','London')) `
                     -SelectedRow $model.TableCursor

    .EXAMPLE
        $hs = New-TeaStyle -Foreground 'BrightCyan' -Bold
        $ss = New-TeaStyle -Foreground 'BrightYellow'
        New-TeaTable -Headers @('Key','Value') -Rows $model.Pairs `
                     -SelectedRow $model.Cursor `
                     -HeaderStyle $hs -SelectedStyle $ss

    .NOTES
        The caller is responsible for tracking SelectedRow and updating it via
        key subscriptions. Rows with fewer cells than the column count are padded
        with empty strings. Extra cells beyond the column count are ignored.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Headers = @(),

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rows,

        [Parameter()]
        [int]$SelectedRow = -1,

        [Parameter()]
        [AllowEmptyCollection()]
        [int[]]$ColumnWidths = @(),

        [Parameter()]
        [PSCustomObject]$Style = $null,

        [Parameter()]
        [PSCustomObject]$HeaderStyle = $null,

        [Parameter()]
        [PSCustomObject]$SelectedStyle = $null
    )

    # Default selected style: bold
    $resolvedSelectedStyle = if ($null -ne $SelectedStyle) {
        $SelectedStyle
    } else {
        [PSCustomObject]@{
            Foreground    = $null
            Background    = $null
            Bold          = $true
            Italic        = $false
            Underline     = $false
            Strikethrough = $false
            Border        = 'None'
            PaddingTop    = 0
            PaddingRight  = 0
            PaddingBottom = 0
            PaddingLeft   = 0
            MarginTop     = 0
            MarginRight   = 0
            MarginBottom  = 0
            MarginLeft    = 0
            Align         = 'Left'
            Width         = $null
            Height        = $null
        }
    }

    # Determine column count
    $hasHeaders = $Headers.Count -gt 0
    $headerCount = $Headers.Count
    $rowCount    = $Rows.Count

    # Find max columns across headers and rows
    $colCount = $headerCount
    foreach ($row in $Rows) {
        $rowArr = @($row)
        if ($rowArr.Count -gt $colCount) { $colCount = $rowArr.Count }
    }

    if ($colCount -eq 0) {
        return [PSCustomObject]@{
            Type      = 'Box'
            Direction = 'Vertical'
            Children  = @([PSCustomObject]@{ Type = 'Text'; Content = ''; Style = $null; Width = 'Auto'; Height = 'Auto' })
            Style     = $Style
            Width     = 'Auto'
            Height    = 'Auto'
        }
    }

    # Calculate column widths
    $resolvedWidths = [int[]]::new($colCount)
    for ($c = 0; $c -lt $colCount; $c++) {
        $w = if ($c -lt $Headers.Count) { $Headers[$c].Length } else { 0 }
        foreach ($row in $Rows) {
            $rowArr = @($row)
            if ($c -lt $rowArr.Count) {
                $cellLen = ([string]$rowArr[$c]).Length
                if ($cellLen -gt $w) { $w = $cellLen }
            }
        }
        $resolvedWidths[$c] = $w
    }

    # Override with explicit widths if provided and counts match
    if ($ColumnWidths.Count -eq $colCount) {
        $resolvedWidths = $ColumnWidths
    }

    # Helper: render a row of cells as padded string
    $renderRow = {
        param([string[]]$cells)
        $parts = for ($c = 0; $c -lt $colCount; $c++) {
            $cell = if ($c -lt $cells.Count) { $cells[$c] } else { '' }
            $cell.PadRight($resolvedWidths[$c])
        }
        $parts -join ' | '
    }

    # Helper: render separator row
    $separatorParts = for ($c = 0; $c -lt $colCount; $c++) {
        '-' * $resolvedWidths[$c]
    }
    $separator = $separatorParts -join '-+-'

    $children = [System.Collections.Generic.List[object]]::new()

    # Header row
    if ($hasHeaders) {
        $paddedHeaders = [string[]]::new($colCount)
        for ($c = 0; $c -lt $colCount; $c++) {
            $paddedHeaders[$c] = if ($c -lt $Headers.Count) { $Headers[$c] } else { '' }
        }
        $headerContent = & $renderRow $paddedHeaders
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $headerContent
            Style   = $HeaderStyle
            Width   = 'Auto'
            Height  = 'Auto'
        })
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $separator
            Style   = $HeaderStyle
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    # Data rows
    for ($r = 0; $r -lt $rowCount; $r++) {
        $rowArr  = [string[]](@($Rows[$r]) | ForEach-Object { [string]$_ })
        $content = & $renderRow $rowArr
        $rowStyle = if ($r -eq $SelectedRow) { $resolvedSelectedStyle } else { $Style }
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $content
            Style   = $rowStyle
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Vertical'
        Children  = $children.ToArray()
        Style     = $Style
        Width     = 'Auto'
        Height    = 'Auto'
    }
}

Set-Alias -Name TeaTable             -Value New-TeaTable

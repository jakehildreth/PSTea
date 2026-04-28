function New-TeaList {
    <#
    .SYNOPSIS
        Creates a scrollable, selectable list view node.

    .DESCRIPTION
        Returns a Box view node rendering a list of string items with one item
        highlighted as selected. The visible window auto-scrolls to keep the
        selected item in view.

        Rendered example (MaxVisible=4, SelectedIndex=2):

            Item A
            Item B
          > Item C   <- selected
            Item D

        The caller is responsible for tracking SelectedIndex in the model and
        updating it via key subscriptions (UpArrow/DownArrow).

    .PARAMETER Items
        Array of strings to display. Required.

    .PARAMETER SelectedIndex
        Zero-based index of the currently selected item. Clamped to valid range.
        Default: 0.

    .PARAMETER MaxVisible
        Maximum number of items to show at once. Default: 10.

    .PARAMETER Prefix
        String prepended to the selected item. Default: '> '.

    .PARAMETER UnselectedPrefix
        String prepended to unselected items. Should match -Prefix in length
        for alignment. Default: '  '.

    .PARAMETER Style
        Base style applied to all unselected items.

    .PARAMETER SelectedStyle
        Style applied to the selected item. When omitted, defaults to bold.

    .OUTPUTS
        PSCustomObject - Box view node.

    .EXAMPLE
        New-TeaList -Items @('Apple', 'Banana', 'Cherry') -SelectedIndex $model.Index

    .EXAMPLE
        $selStyle = New-TeaStyle -Foreground 'BrightYellow' -Bold
        New-TeaList -Items $model.Items -SelectedIndex $model.Cursor `
                    -MaxVisible 8 -SelectedStyle $selStyle

    .NOTES
        The visible window is calculated automatically: if SelectedIndex is
        outside the current window, the window shifts to keep it visible.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Items,

        [Parameter()]
        [int]$SelectedIndex = 0,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxVisible = 10,

        [Parameter()]
        [string]$Prefix = '> ',

        [Parameter()]
        [string]$UnselectedPrefix = '  ',

        [Parameter()]
        [PSCustomObject]$Style = $null,

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

    $count = $Items.Count

    if ($count -eq 0) {
        return [PSCustomObject]@{
            Type      = 'Box'
            Direction = 'Vertical'
            Children  = @([PSCustomObject]@{ Type = 'Text'; Content = ''; Style = $null; Width = 'Auto'; Height = 'Auto' })
            Style     = $Style
            Width     = 'Auto'
            Height    = 'Auto'
        }
    }

    # Clamp selected index
    $sel = [math]::Max(0, [math]::Min($SelectedIndex, $count - 1))

    # Calculate scroll offset so selected item stays visible
    $scrollOffset = 0
    if ($sel -ge $MaxVisible) {
        $scrollOffset = $sel - $MaxVisible + 1
    }
    $endIdx = [math]::Min($scrollOffset + $MaxVisible, $count) - 1

    $children = [System.Collections.Generic.List[object]]::new()
    for ($i = $scrollOffset; $i -le $endIdx; $i++) {
        $isSelected = ($i -eq $sel)
        $itemPrefix = if ($isSelected) { $Prefix } else { $UnselectedPrefix }
        $content    = $itemPrefix + $Items[$i]
        $itemStyle  = if ($isSelected) { $resolvedSelectedStyle } else { $Style }

        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $content
            Style   = $itemStyle
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Vertical'
        Children  = $children.ToArray()
        Style     = $null
        Width     = 'Auto'
        Height    = 'Auto'
    }
}

Set-Alias -Name TeaList              -Value New-TeaList

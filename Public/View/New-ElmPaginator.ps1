function New-ElmPaginator {
    <#
    .SYNOPSIS
        Creates a paginator or tab bar view node.

    .DESCRIPTION
        Returns a view node representing a numeric page indicator, a dot row, or
        a named tab bar, depending on the parameter set used.

        Numeric mode (default):

            < 3 / 7 >

        The `<` and `>` indicators are replaced with spaces when at the first or
        last page respectively, giving a stable width.

        Dots mode (-Dots switch):

            ○ ○ ● ○ ○ ○ ○

        Each page is a separate Text child inside a horizontal Box. The active
        page uses FilledDot; others use EmptyDot. Chars are configurable for
        terminals that do not support Unicode.

        Named-tab mode (-Tabs):

            Tab1  |  [Tab2]  |  Tab3

        Each tab label is a separate Text child node inside a horizontal Box. The
        active tab is wrapped in brackets and receives ActiveStyle; inactive tabs
        receive Style.

    .PARAMETER CurrentPage
        One-based current page number. Clamped to [1, PageCount]. Used in
        Numeric and Dots modes.

    .PARAMETER PageCount
        Total number of pages. Minimum 1. Used in Numeric and Dots modes.

    .PARAMETER Dots
        Switch that selects Dots mode. Required to disambiguate from Numeric
        when no dot-specific parameters are passed.

    .PARAMETER FilledDot
        Character string for the active page dot. Default: '●' (U+25CF).
        Use ASCII alternatives (e.g. '*') for terminals without Unicode support.

    .PARAMETER EmptyDot
        Character string for inactive page dots. Default: '○' (U+25CB).
        Use ASCII alternatives (e.g. '-') for terminals without Unicode support.

    .PARAMETER Separator
        String inserted between each dot. Default: ' '.

    .PARAMETER Tabs
        Array of tab label strings. Used in named-tab mode.

    .PARAMETER ActiveTab
        Zero-based index of the active tab. Clamped to [0, Tabs.Count-1]. Used
        in named-tab mode.

    .PARAMETER Style
        Elm style applied to the full text node (Numeric), inactive dots (Dots),
        or inactive tab labels (Tabs).

    .PARAMETER ActiveStyle
        Elm style applied to the active element. Falls back to Style when null.

    .OUTPUTS
        PSCustomObject - Text node (Numeric), Box/Horizontal (Dots or Tabs).

    .EXAMPLE
        # Numeric pagination
        New-ElmPaginator -CurrentPage $model.Page -PageCount $model.TotalPages

    .EXAMPLE
        # Dot pagination with defaults
        New-ElmPaginator -Dots -CurrentPage $model.Page -PageCount $model.TotalPages

    .EXAMPLE
        # Dot pagination - ASCII-safe for Windows PowerShell 5.1
        New-ElmPaginator -Dots -CurrentPage 3 -PageCount 5 -FilledDot '*' -EmptyDot '-'

    .EXAMPLE
        # Named tabs
        $activeStyle = New-ElmStyle -Foreground 'BrightWhite' -Bold
        New-ElmPaginator -Tabs @('Overview','Details','Logs') `
                         -ActiveTab $model.Tab `
                         -ActiveStyle $activeStyle

    .NOTES
        In Dots mode, UTF-8 console encoding is required for the default Unicode
        dot chars to render correctly. New-ElmTerminalDriver sets this automatically.

        In named-tab mode, a ' | ' Text node is inserted between each tab as a
        separator. The caller manages ActiveTab index via key subscriptions.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Numeric')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Numeric')]
        [Parameter(Mandatory, ParameterSetName = 'Dots')]
        [int]$CurrentPage,

        [Parameter(Mandatory, ParameterSetName = 'Numeric')]
        [Parameter(Mandatory, ParameterSetName = 'Dots')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$PageCount,

        [Parameter(Mandatory, ParameterSetName = 'Dots')]
        [switch]$Dots,

        [Parameter(ParameterSetName = 'Dots')]
        [ValidateNotNullOrEmpty()]
        [string]$FilledDot = ([char]0x25CF).ToString(),   # ●

        [Parameter(ParameterSetName = 'Dots')]
        [ValidateNotNullOrEmpty()]
        [string]$EmptyDot = ([char]0x25CB).ToString(),    # ○

        [Parameter(ParameterSetName = 'Dots')]
        [string]$Separator = ' ',

        [Parameter(Mandatory, ParameterSetName = 'Tabs')]
        [ValidateCount(1, [int]::MaxValue)]
        [string[]]$Tabs,

        [Parameter(Mandatory, ParameterSetName = 'Tabs')]
        [int]$ActiveTab,

        [Parameter()]
        [PSCustomObject]$Style = $null,

        [Parameter()]
        [PSCustomObject]$ActiveStyle = $null
    )

    $resolvedActiveStyle = if ($null -ne $ActiveStyle) { $ActiveStyle } else { $Style }

    if ($PSCmdlet.ParameterSetName -eq 'Numeric') {
        $page = [math]::Max(1, [math]::Min($CurrentPage, $PageCount))

        $left    = if ($page -gt 1)          { '<' } else { ' ' }
        $right   = if ($page -lt $PageCount) { '>' } else { ' ' }
        $content = "$left $page / $PageCount $right"

        return [PSCustomObject]@{
            Type    = 'Text'
            Content = $content
            Style   = $resolvedActiveStyle
            Width   = 'Auto'
            Height  = 'Auto'
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Dots') {
        $page     = [math]::Max(1, [math]::Min($CurrentPage, $PageCount))
        $children = [System.Collections.Generic.List[object]]::new()

        for ($i = 1; $i -le $PageCount; $i++) {
            if ($i -gt 1) {
                $children.Add([PSCustomObject]@{
                    Type    = 'Text'
                    Content = $Separator
                    Style   = $Style
                    Width   = 'Auto'
                    Height  = 'Auto'
                })
            }

            $isActive = $i -eq $page
            $children.Add([PSCustomObject]@{
                Type    = 'Text'
                Content = if ($isActive) { $FilledDot } else { $EmptyDot }
                Style   = if ($isActive) { $resolvedActiveStyle } else { $Style }
                Width   = 'Auto'
                Height  = 'Auto'
            })
        }

        return [PSCustomObject]@{
            Type      = 'Box'
            Direction = 'Horizontal'
            Children  = $children.ToArray()
            Width     = 'Auto'
            Height    = 'Auto'
        }
    }

    # Named-tab mode
    $clampedTab = [math]::Max(0, [math]::Min($ActiveTab, $Tabs.Count - 1))

    $children = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $Tabs.Count; $i++) {
        if ($i -gt 0) {
            $children.Add([PSCustomObject]@{
                Type    = 'Text'
                Content = ' | '
                Style   = $Style
                Width   = 'Auto'
                Height  = 'Auto'
            })
        }

        $isActive = $i -eq $clampedTab
        $label    = if ($isActive) { "[$($Tabs[$i])]" } else { $Tabs[$i] }
        $children.Add([PSCustomObject]@{
            Type    = 'Text'
            Content = $label
            Style   = if ($isActive) { $resolvedActiveStyle } else { $Style }
            Width   = 'Auto'
            Height  = 'Auto'
        })
    }

    return [PSCustomObject]@{
        Type      = 'Box'
        Direction = 'Horizontal'
        Children  = $children.ToArray()
        Style     = $Style
        Width     = 'Auto'
        Height    = 'Auto'
    }
}

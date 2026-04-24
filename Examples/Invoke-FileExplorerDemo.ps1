Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# File explorer demo
# Navigate the filesystem with arrow keys, Enter to open directories.
# Demonstrates: real PS integration, two-pane layout, scrollable list,
# script-scoped item cache (keeps Items out of the model to avoid
# expensive JSON roundtrips in Copy-ElmModel on every keypress)
# ---------------------------------------------------------------------------

# Cache: path -> items array. Never serialized as part of the model.
$script:explorerCache = @{}

function Get-CachedItems {
    param([string]$Path)
    if (-not $script:explorerCache.ContainsKey($Path)) {
        $parentPath = [System.IO.Path]::GetDirectoryName($Path)
        $dotDot = if ($null -ne $parentPath -and (Test-Path -LiteralPath $parentPath)) {
            @([PSCustomObject]@{
                Name          = '..'
                FullName      = $parentPath
                PSIsContainer = $true
                Length        = 0L
                LastWriteTime = ''
            })
        } else { @() }
        $raw = @(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
            Sort-Object -Property @{Expression = { $_.PSIsContainer }; Descending = $true }, Name)
        $entries = @($raw | ForEach-Object {
            [PSCustomObject]@{
                Name          = [string]$_.Name
                FullName      = [string]$_.FullName
                PSIsContainer = [bool]$_.PSIsContainer
                Length        = if ($_.PSIsContainer) { 0L } else { [long]$_.Length }
                LastWriteTime = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            }
        })
        $script:explorerCache[$Path] = @($dotDot) + $entries
    }
    $script:explorerCache[$Path]
}

function Format-ItemSize {
    param([long]$Bytes)
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N1} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

$visibleCount = 14

$init = {
    $startPath = (Get-Location).Path
    $null = Get-CachedItems -Path $startPath
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Path = $startPath; Cursor = 0; Offset = 0 }
        Cmd   = $null
    }
}

$update = {
    param($msg, $model)

    $items     = @(Get-CachedItems -Path $model.Path)
    $itemCount = $items.Count

    switch ($msg.Key) {
        'UpArrow' {
            if ($itemCount -eq 0) { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $newCursor = if ($model.Cursor -gt 0) { $model.Cursor - 1 } else { $model.Cursor }
            $newOffset = if ($newCursor -lt $model.Offset) { $newCursor } else { $model.Offset }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Path = $model.Path; Cursor = $newCursor; Offset = $newOffset }
                Cmd   = $null
            }
        }
        'DownArrow' {
            if ($itemCount -eq 0) { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $newCursor = if ($model.Cursor -lt $itemCount - 1) { $model.Cursor + 1 } else { $model.Cursor }
            $newOffset = if ($newCursor -ge $model.Offset + $visibleCount) { $newCursor - $visibleCount + 1 } else { $model.Offset }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ Path = $model.Path; Cursor = $newCursor; Offset = $newOffset }
                Cmd   = $null
            }
        }
        'Enter' {
            if ($itemCount -eq 0) { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
            $selected = $items[$model.Cursor]
            if ($selected.PSIsContainer) {
                $newPath = $selected.FullName
                $null = Get-CachedItems -Path $newPath
                return [PSCustomObject]@{
                    Model = [PSCustomObject]@{ Path = $newPath; Cursor = 0; Offset = 0 }
                    Cmd   = $null
                }
            }
            return [PSCustomObject]@{ Model = $model; Cmd = $null }
        }
        'Q' {
            return [PSCustomObject]@{
                Model = $model
                Cmd   = [PSCustomObject]@{ Type = 'Quit' }
            }
        }
    }

    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

$view = {
    param($model)

    $titleStyle    = New-ElmStyle -Foreground 'BrightCyan' -Bold
    $pathStyle     = New-ElmStyle -Foreground 'BrightBlack'
    $selectedStyle = New-ElmStyle -Foreground 'BrightYellow' -Bold
    $dirStyle      = New-ElmStyle -Foreground 'BrightBlue'
    $fileStyle     = New-ElmStyle -Foreground 'White'
    $labelStyle    = New-ElmStyle -Foreground 'BrightBlack'
    $valueStyle    = New-ElmStyle -Foreground 'BrightWhite'
    $hintStyle     = New-ElmStyle -Foreground 'BrightBlack'
    $leftStyle     = New-ElmStyle -Border 'Normal' -Width 34 -Padding @(0, 1)
    $rightStyle    = New-ElmStyle -Border 'Normal' -Width 'Fill' -Padding @(0, 1)

    $items     = @(Get-CachedItems -Path $model.Path)
    $itemCount = $items.Count

    # Left pane: scrollable file list
    $listNodes = @()
    if ($itemCount -eq 0) {
        $listNodes += New-ElmText -Content '(empty)' -Style $labelStyle
    } else {
        $end = [Math]::Min($model.Offset + $visibleCount - 1, $itemCount - 1)
        for ($i = $model.Offset; $i -le $end; $i++) {
            $item      = $items[$i]
            $isDir     = $item.PSIsContainer
            $rawName   = $item.Name
            $name      = if ($rawName.Length -gt 28) { $rawName.Substring(0, 25) + '...' } else { $rawName }
            $prefix    = if ($isDir) { '[>] ' } else { '    ' }
            $baseStyle = if ($isDir) { $dirStyle } else { $fileStyle }
            $style     = if ($i -eq $model.Cursor) { $selectedStyle } else { $baseStyle }
            $listNodes += New-ElmText -Content "$prefix$name" -Style $style
        }
    }

    $leftPane = New-ElmBox -Style $leftStyle -Children $listNodes

    # Right pane: selected item details
    $rightNodes = @()
    if ($itemCount -gt 0) {
        $sel = $items[$model.Cursor]
        $rightNodes += New-ElmText -Content 'Name' -Style $labelStyle
        $rightNodes += New-ElmText -Content $sel.Name -Style $valueStyle
        $rightNodes += New-ElmText -Content ''
        $rightNodes += New-ElmText -Content 'Type' -Style $labelStyle
        $rightNodes += New-ElmText -Content $(if ($sel.PSIsContainer) { 'Directory' } else { 'File' }) -Style $valueStyle

        if (-not $sel.PSIsContainer) {
            $rightNodes += New-ElmText -Content ''
            $rightNodes += New-ElmText -Content 'Size' -Style $labelStyle
            $rightNodes += New-ElmText -Content (Format-ItemSize -Bytes $sel.Length) -Style $valueStyle
        }

        if ($sel.LastWriteTime -ne '') {
            $rightNodes += New-ElmText -Content ''
            $rightNodes += New-ElmText -Content 'Modified' -Style $labelStyle
            $rightNodes += New-ElmText -Content $sel.LastWriteTime -Style $valueStyle
        }
    } else {
        $rightNodes += New-ElmText -Content '(no selection)' -Style $labelStyle
    }

    $rightPane = New-ElmBox -Style $rightStyle -Children $rightNodes

    $displayPath = $model.Path
    if ($displayPath.Length -gt 60) { $displayPath = '...' + $displayPath.Substring($displayPath.Length - 57) }
    $scrollInfo = if ($itemCount -gt 0) { " ($($model.Cursor + 1)/$itemCount)" } else { '' }

    New-ElmBox -Children @(
        New-ElmText -Content 'File Explorer' -Style $titleStyle
        New-ElmText -Content "$displayPath$scrollInfo" -Style $pathStyle
        New-ElmRow -Children @($leftPane, $rightPane)
        New-ElmText -Content '[Up/Down] navigate  [Enter] open dir / ..  [Q] quit' -Style $hintStyle
    )
}

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

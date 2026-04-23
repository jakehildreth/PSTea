function Apply-ElmStyle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter()]
        [int]$Width = -1,

        [Parameter()]
        [object]$Style
    )

    if ($null -eq $Style) {
        return $Content
    }

    # Use provided Width when >= 0; otherwise fall back to content display length
    $effectiveWidth = if ($Width -ge 0) { $Width } else { $Content.Length }

    $esc   = [char]27
    $reset = "$esc[0m"

    # Step 1: Apply SGR text decorations and colors to content
    $styledContent = $Content

    if ($null -ne $Style.Foreground) {
        $fgSeq = Resolve-ElmColor -Color $Style.Foreground -IsForeground
        $styledContent = "$fgSeq$styledContent$reset"
    }

    if ($null -ne $Style.Background) {
        $bgSeq = Resolve-ElmColor -Color $Style.Background
        $styledContent = "$bgSeq$styledContent$reset"
    }

    $sgrCodes = @()
    if ($Style.Bold)          { $sgrCodes += '1' }
    if ($Style.Italic)        { $sgrCodes += '3' }
    if ($Style.Underline)     { $sgrCodes += '4' }
    if ($Style.Strikethrough) { $sgrCodes += '9' }

    if ($sgrCodes.Count -gt 0) {
        $sgrSeq = "$esc[$($sgrCodes -join ';')m"
        $styledContent = "$sgrSeq$styledContent$reset"
    }

    # Step 2: Apply padding (visual space chars around styled content)
    $paddingTop    = [int]$Style.PaddingTop
    $paddingRight  = [int]$Style.PaddingRight
    $paddingBottom = [int]$Style.PaddingBottom
    $paddingLeft   = [int]$Style.PaddingLeft

    # Visual width of the padded block (escape sequences don't consume columns)
    $paddedWidth = $effectiveWidth + $paddingLeft + $paddingRight

    $lines = @()
    for ($i = 0; $i -lt $paddingTop; $i++) {
        $lines += ' ' * $paddedWidth
    }
    $lines += (' ' * $paddingLeft) + $styledContent + (' ' * $paddingRight)
    for ($i = 0; $i -lt $paddingBottom; $i++) {
        $lines += ' ' * $paddedWidth
    }

    # Step 3: Apply border (box-drawing chars around padded block)
    if ($Style.Border -ne 'None') {
        $chars      = ConvertTo-BorderChars -Style $Style.Border
        $topLine    = $chars.TL + ($chars.T * $paddedWidth) + $chars.TR
        $bottomLine = $chars.BL + ($chars.B * $paddedWidth) + $chars.BR
        $bordered   = @($topLine)
        foreach ($line in $lines) {
            $bordered += $chars.L + $line + $chars.R
        }
        $bordered += $bottomLine
        $lines = $bordered
    }

    # Step 4: Apply margin (outer spacing around bordered block)
    $marginTop    = [int]$Style.MarginTop
    $marginRight  = [int]$Style.MarginRight
    $marginBottom = [int]$Style.MarginBottom
    $marginLeft   = [int]$Style.MarginLeft

    $result = @()
    for ($i = 0; $i -lt $marginTop; $i++) {
        $result += ''
    }
    foreach ($line in $lines) {
        $result += (' ' * $marginLeft) + $line + (' ' * $marginRight)
    }
    for ($i = 0; $i -lt $marginBottom; $i++) {
        $result += ''
    }

    return $result -join "`n"
}

function ConvertTo-AnsiPatch {
    <#
    .SYNOPSIS
        Converts a list of view-diff patches into an incremental ANSI escape sequence string.

    .DESCRIPTION
        Processes each patch from Compare-ElmViewTree:

        - Replace: emits a cursor-position sequence (ESC[{Y+1};{X+1}H) followed by
          the styled content from Apply-ElmStyle.
        - Clear: emits a cursor-position sequence followed by spaces spanning Width
          for each row in Height, erasing the vacated region.
        - FullRedraw: skipped. The caller is expected to detect FullRedraw patches
          and invoke ConvertTo-AnsiOutput instead.

    .PARAMETER Patches
        An array of patch PSCustomObjects produced by Compare-ElmViewTree. Each object
        has a Type property ('Replace', 'Clear', or 'FullRedraw').

    .OUTPUTS
        [string] — A single ANSI escape sequence string ready for Console output.
        Returns an empty string when the patch list is empty or contains only FullRedraw.

    .EXAMPLE
        $patches = Compare-ElmViewTree -OldTree $prev -NewTree $new
        $ansi    = ConvertTo-AnsiPatch -Patches $patches
        [Console]::Out.Write($ansi)

    .NOTES
        Does not emit hide/show cursor or clear-screen sequences. The caller (event loop)
        manages cursor visibility around full renders.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Patches
    )

    $esc = [char]27
    $sb  = [System.Text.StringBuilder]::new()

    foreach ($patch in $Patches) {
        switch ($patch.Type) {
            'Replace' {
                $row        = $patch.Y + 1
                $col        = $patch.X + 1
                $patchWidth  = if ($patch.PSObject.Properties['Width']    -and $null -ne $patch.Width)    { $patch.Width }    else { $patch.Content.Length }
                $oldWidth    = if ($patch.PSObject.Properties['OldWidth'] -and $null -ne $patch.OldWidth) { $patch.OldWidth } else { $patchWidth }
                $clearWidth  = [Math]::Max($patchWidth, $oldWidth)
                $content     = Apply-ElmStyle -Content $patch.Content -Style $patch.Style -Width $patchWidth
                # Compute visual width of styled output (SGR codes are zero-width).
                # Append trailing spaces to fill clearWidth, overwriting stale chars from shorter-to-longer transitions.
                $visualLen = $patch.Content.Length
                if ($null -ne $patch.Style) {
                    $visualLen += [int]$patch.Style.PaddingLeft + [int]$patch.Style.PaddingRight
                }
                $trailer = ' ' * [Math]::Max(0, $clearWidth - $visualLen)
                [void]$sb.Append($esc + "[$row;${col}H" + $content + $trailer)
            }
            'Clear' {
                $row    = $patch.Y + 1
                $col    = $patch.X + 1
                $spaces = ' ' * $patch.Width
                for ($r = 0; $r -lt $patch.Height; $r++) {
                    $currentRow = $row + $r
                    [void]$sb.Append("$esc[$currentRow;${col}H$spaces")
                }
            }
            'FullRedraw' {
                # Intentionally skipped — caller handles full-redraw via ConvertTo-AnsiOutput
            }
        }
    }

    return $sb.ToString()
}

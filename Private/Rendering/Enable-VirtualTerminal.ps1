function Enable-VirtualTerminal {
    <#
    .SYNOPSIS
        Enables VT100/ANSI virtual terminal processing on Windows.

    .DESCRIPTION
        On macOS/Linux (PS7+), ANSI escape sequences are supported natively and this
        function returns $true immediately. On Windows, it uses the Win32 SetConsoleMode
        API via Add-Type P/Invoke to enable ENABLE_VIRTUAL_TERMINAL_PROCESSING on stdout.
        Returns $true on success, $false if the mode could not be set.

    .OUTPUTS
        [bool] - $true if VT processing is enabled, $false if it could not be enabled.
    #>
    [CmdletBinding()]
    # Determine if running on Windows; $IsWindows does not exist in PS 5.1
    $onWindows = if ($null -ne $IsWindows) { $IsWindows } else { $true }

    if (-not $onWindows) {
        # PS7+ on Linux/macOS supports ANSI natively
        return $true
    }

    try {
        if (-not ([System.Management.Automation.PSTypeName]'TeaConsoleHelper').Type) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TeaConsoleHelper {
    public const int  STD_OUTPUT_HANDLE                  = -11;
    public const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
}
'@
        }

        $handle = [TeaConsoleHelper]::GetStdHandle([TeaConsoleHelper]::STD_OUTPUT_HANDLE)
        $mode = [uint32]0

        if (-not [TeaConsoleHelper]::GetConsoleMode($handle, [ref]$mode)) {
            Write-Warning 'Enable-VirtualTerminal: GetConsoleMode failed.'
            return $false
        }

        $newMode = $mode -bor [TeaConsoleHelper]::ENABLE_VIRTUAL_TERMINAL_PROCESSING

        if (-not [TeaConsoleHelper]::SetConsoleMode($handle, $newMode)) {
            Write-Warning 'Enable-VirtualTerminal: SetConsoleMode failed.'
            return $false
        }

        return $true
    } catch {
        Write-Warning "Enable-VirtualTerminal: $_"
        return $false
    }
}



function Enable-VirtualTerminal {
    # Determine if running on Windows; $IsWindows does not exist in PS 5.1
    $onWindows = if ($null -ne $IsWindows) { $IsWindows } else { $true }

    if (-not $onWindows) {
        # PS7+ on Linux/macOS supports ANSI natively
        return $true
    }

    try {
        if (-not ([System.Management.Automation.PSTypeName]'ElmConsoleHelper').Type) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ElmConsoleHelper {
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

        $handle = [ElmConsoleHelper]::GetStdHandle([ElmConsoleHelper]::STD_OUTPUT_HANDLE)
        $mode = [uint32]0

        if (-not [ElmConsoleHelper]::GetConsoleMode($handle, [ref]$mode)) {
            Write-Warning 'Enable-VirtualTerminal: GetConsoleMode failed.'
            return $false
        }

        $newMode = $mode -bor [ElmConsoleHelper]::ENABLE_VIRTUAL_TERMINAL_PROCESSING

        if (-not [ElmConsoleHelper]::SetConsoleMode($handle, $newMode)) {
            Write-Warning 'Enable-VirtualTerminal: SetConsoleMode failed.'
            return $false
        }

        return $true
    } catch {
        Write-Warning "Enable-VirtualTerminal: $_"
        return $false
    }
}

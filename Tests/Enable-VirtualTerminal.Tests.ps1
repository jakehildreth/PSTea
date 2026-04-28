BeforeAll {
    . $PSScriptRoot/../Private/Rendering/Enable-VirtualTerminal.ps1
}

Describe 'Enable-VirtualTerminal' -Tag 'Unit', 'P1' {
    Context 'When running on non-Windows (PS7+)' {
        It 'Should return $true without invoking P/Invoke' -Skip:(-not (($PSVersionTable.PSVersion.Major -ge 7) -and (-not $IsWindows))) {
            $result = Enable-VirtualTerminal
            $result | Should -BeTrue
        }

        It 'Should not define TeaConsoleHelper type' -Skip:(-not (($PSVersionTable.PSVersion.Major -ge 7) -and (-not $IsWindows))) {
            Enable-VirtualTerminal | Out-Null
            [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() |
                Where-Object { $_.Name -eq 'TeaConsoleHelper' } |
                Should -BeNullOrEmpty
        }
    }

    Context 'When running on Windows with a working console' {
        It 'Should return $true when SetConsoleMode succeeds' -Skip:(-not ($IsWindows -eq $true -or $PSVersionTable.PSEdition -eq 'Desktop')) {
            $result = Enable-VirtualTerminal
            $result | Should -BeTrue
        }

        It 'Should not throw even when console mode operations fail' -Skip:(-not ($IsWindows -eq $true -or $PSVersionTable.PSEdition -eq 'Desktop')) {
            { Enable-VirtualTerminal } | Should -Not -Throw
        }
    }

    Context 'Return type' {
        It 'Should return a boolean' {
            $result = Enable-VirtualTerminal
            $result | Should -BeOfType [bool]
        }
    }
}

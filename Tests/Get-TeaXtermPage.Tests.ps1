BeforeAll {
    # Stub script-scoped web asset variables so the function works without module import
    $script:XtermJs       = '/* xterm-stub */'
    $script:XtermAddonFit = '/* fit-stub */'
    $script:XtermCss      = '/* css-stub */'

    . $PSScriptRoot/../Private/Web/Get-TeaXtermPage.ps1
}

Describe 'Get-TeaXtermPage' {

    Context 'HTML structure' {
        BeforeAll {
            $script:html = Get-TeaXtermPage -Port 8080 -Cols 220 -Rows 50 -Title 'Test App'
        }

        It 'Should return a non-empty string' {
            $script:html | Should -Not -BeNullOrEmpty
        }

        It 'Should include DOCTYPE declaration' {
            $script:html | Should -Match '(?i)<!DOCTYPE html>'
        }

        It 'Should include the provided title' {
            $script:html | Should -Match '<title>Test App</title>'
        }

        It 'Should include a #terminal div' {
            $script:html | Should -Match 'id="terminal"'
        }

        It 'Should include the stubbed xterm.js content' {
            $script:html | Should -Match 'xterm-stub'
        }

        It 'Should include the stubbed xterm-addon-fit content' {
            $script:html | Should -Match 'fit-stub'
        }
    }

    Context 'Port substitution' {
        It 'Should embed the correct port in the WebSocket URL' {
            $html = Get-TeaXtermPage -Port 9999 -Cols 80 -Rows 24
            $html | Should -Match "ws://localhost:9999/ws"
        }

        It 'Should embed the correct port for a different port number' {
            $html = Get-TeaXtermPage -Port 1234 -Cols 80 -Rows 24
            $html | Should -Match "ws://localhost:1234/ws"
        }
    }

    Context 'Terminal dimensions' {
        It 'Should embed the correct cols in Terminal constructor' {
            $html = Get-TeaXtermPage -Port 8080 -Cols 160 -Rows 40
            $html | Should -Match 'cols:\s*160'
        }

        It 'Should embed the correct rows in Terminal constructor' {
            $html = Get-TeaXtermPage -Port 8080 -Cols 160 -Rows 40
            $html | Should -Match 'rows:\s*40'
        }
    }

    Context 'JavaScript event handler syntax' {
        BeforeAll {
            $script:html = Get-TeaXtermPage -Port 8080 -Cols 220 -Rows 50
        }

        It 'Should use assignment syntax for ws.onmessage (not method-call syntax)' {
            # Must be: ws.onmessage = ... NOT ws.onmessage(
            $script:html | Should -Match 'ws\.onmessage\s*='
            $script:html | Should -Not -Match 'ws\.onmessage\('
        }

        It 'Should use assignment syntax for ws.onopen' {
            $script:html | Should -Match 'ws\.onopen\s*='
        }

        It 'Should use assignment syntax for ws.onclose' {
            $script:html | Should -Match 'ws\.onclose\s*='
        }

        It 'Should use assignment syntax for ws.onerror' {
            $script:html | Should -Match 'ws\.onerror\s*='
        }

        It 'Should include FitAddon with correct UMD class path (FitAddon.FitAddon)' {
            $script:html | Should -Match 'FitAddon\.FitAddon'
        }

        It 'Should include reconnect logic (setTimeout)' {
            $script:html | Should -Match 'setTimeout'
        }

        It 'Should send data via term.onData' {
            $script:html | Should -Match 'term\.onData'
        }
    }

    Context 'Defaults' {
        It 'Should use "PSTea TUI" as default title' {
            $html = Get-TeaXtermPage -Port 8080
            $html | Should -Match '<title>PSTea TUI</title>'
        }
    }
}

BeforeAll {
    . $PSScriptRoot/../Public/View/New-ElmText.ps1
}

Describe 'New-ElmText' {
    Context 'When called with a content string' {
        It 'Should return a PSCustomObject' {
            $result = New-ElmText -Content 'hello'
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Type = Text' {
            $result = New-ElmText -Content 'hello'
            $result.Type | Should -Be 'Text'
        }

        It 'Should store the content' {
            $result = New-ElmText -Content 'hello'
            $result.Content | Should -Be 'hello'
        }

        It 'Should default Style to $null' {
            $result = New-ElmText -Content 'hello'
            $result.Style | Should -BeNullOrEmpty
        }

        It 'Should default Width to Auto' {
            $result = New-ElmText -Content 'hello'
            $result.Width | Should -Be 'Auto'
        }

        It 'Should default Height to Auto' {
            $result = New-ElmText -Content 'hello'
            $result.Height | Should -Be 'Auto'
        }
    }

    Context 'When -Style is provided' {
        BeforeAll {
            . $PSScriptRoot/../Public/Style/New-ElmStyle.ps1
        }

        It 'Should store the provided style' {
            $style = New-ElmStyle -Bold
            $result = New-ElmText -Content 'hello' -Style $style
            $result.Style | Should -Not -BeNullOrEmpty
            $result.Style.Bold | Should -BeTrue
        }
    }

    Context 'When -Content is null' {
        It 'Should throw a terminating error' {
            { New-ElmText -Content $null } | Should -Throw
        }
    }

    Context 'When -Content is empty string' {
        It 'Should throw a terminating error' {
            { New-ElmText -Content '' } | Should -Throw
        }
    }
}

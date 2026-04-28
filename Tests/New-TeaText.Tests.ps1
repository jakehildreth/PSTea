BeforeAll {
    . $PSScriptRoot/../Public/View/New-TeaText.ps1
}

Describe 'New-TeaText' {
    Context 'When called with a content string' {
        It 'Should return a PSCustomObject' {
            $result = New-TeaText -Content 'hello'
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should have Type = Text' {
            $result = New-TeaText -Content 'hello'
            $result.Type | Should -Be 'Text'
        }

        It 'Should store the content' {
            $result = New-TeaText -Content 'hello'
            $result.Content | Should -Be 'hello'
        }

        It 'Should default Style to $null' {
            $result = New-TeaText -Content 'hello'
            $result.Style | Should -BeNullOrEmpty
        }

        It 'Should default Width to Auto' {
            $result = New-TeaText -Content 'hello'
            $result.Width | Should -Be 'Auto'
        }

        It 'Should default Height to Auto' {
            $result = New-TeaText -Content 'hello'
            $result.Height | Should -Be 'Auto'
        }
    }

    Context 'When -Style is provided' {
        BeforeAll {
            . $PSScriptRoot/../Public/Style/New-TeaStyle.ps1
        }

        It 'Should store the provided style' {
            $style = New-TeaStyle -Bold
            $result = New-TeaText -Content 'hello' -Style $style
            $result.Style | Should -Not -BeNullOrEmpty
            $result.Style.Bold | Should -BeTrue
        }
    }

    Context 'When -Content is null' {
        It 'Should coerce null to empty string and return a Text node' {
            $result = New-TeaText -Content $null
            $result.Content | Should -Be ''
        }
    }

    Context 'When -Content is empty string' {
        It 'Should return a Text node with empty Content for blank lines' {
            $result = New-TeaText -Content ''
            $result.Content | Should -Be ''
        }
    }
}

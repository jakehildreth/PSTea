Import-Module "$PSScriptRoot/../Elm.psd1" -Force

# ---------------------------------------------------------------------------
# Quiz demo
# Five PowerShell/Elm-Architecture multiple-choice questions.
# Demonstrates: multi-phase views (Quiz -> Results), answer tracking,
# conditional rendering based on model state
# ---------------------------------------------------------------------------

$questions = @(
    [PSCustomObject]@{
        Text    = 'What does TEA stand for?'
        Options = @(
            'Terminal Elm Architecture'
            'The Elm Architecture'
            'Typed Event Abstraction'
            'Terminal Event Adapter'
        )
        Answer  = 1
    }
    [PSCustomObject]@{
        Text    = 'Which PowerShell version introduced classes?'
        Options = @(
            'PowerShell 3.0'
            'PowerShell 4.0'
            'PowerShell 5.0'
            'PowerShell 6.0'
        )
        Answer  = 2
    }
    [PSCustomObject]@{
        Text    = 'In the Elm Architecture, which function handles messages?'
        Options = @(
            'InitFn'
            'UpdateFn'
            'ViewFn'
            'DispatchFn'
        )
        Answer  = 1
    }
    [PSCustomObject]@{
        Text    = 'What ANSI escape sequence hides the terminal cursor?'
        Options = @(
            'ESC[0m'
            'ESC[2J'
            'ESC[?25l'
            'ESC[?25h'
        )
        Answer  = 2
    }
    [PSCustomObject]@{
        Text    = 'What does Compare-ElmViewTree return on the very first render?'
        Options = @(
            'Empty list'
            'Clear patch'
            'Replace patch'
            'FullRedraw patch'
        )
        Answer  = 3
    }
)

$init = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Questions     = $questions
            QuestionIndex = 0
            Selected      = 0
            Answers       = @()
            Phase         = 'Quiz'
        }
        Cmd = $null
    }
}

$update = {
    param($msg, $model)

    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{
            Model = $model
            Cmd   = [PSCustomObject]@{ Type = 'Quit' }
        }
    }

    if ($model.Phase -eq 'Results') {
        if ($msg.Key -eq 'R') {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Questions     = $model.Questions
                    QuestionIndex = 0
                    Selected      = 0
                    Answers       = @()
                    Phase         = 'Quiz'
                }
                Cmd = $null
            }
        }
        return [PSCustomObject]@{ Model = $model; Cmd = $null }
    }

    $q        = $model.Questions[$model.QuestionIndex]
    $optCount = @($q.Options).Count

    switch ($msg.Key) {
        'UpArrow' {
            $newSel = if ($model.Selected -gt 0) { $model.Selected - 1 } else { $optCount - 1 }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Questions     = $model.Questions
                    QuestionIndex = $model.QuestionIndex
                    Selected      = $newSel
                    Answers       = $model.Answers
                    Phase         = 'Quiz'
                }
                Cmd = $null
            }
        }
        'DownArrow' {
            $newSel = if ($model.Selected -lt $optCount - 1) { $model.Selected + 1 } else { 0 }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Questions     = $model.Questions
                    QuestionIndex = $model.QuestionIndex
                    Selected      = $newSel
                    Answers       = $model.Answers
                    Phase         = 'Quiz'
                }
                Cmd = $null
            }
        }
        'Enter' {
            $correct    = ($model.Selected -eq $q.Answer)
            $newAnswers = @($model.Answers) + @($correct)
            $nextIndex  = $model.QuestionIndex + 1
            $nextPhase  = if ($nextIndex -ge @($model.Questions).Count) { 'Results' } else { 'Quiz' }
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Questions     = $model.Questions
                    QuestionIndex = $nextIndex
                    Selected      = 0
                    Answers       = $newAnswers
                    Phase         = $nextPhase
                }
                Cmd = $null
            }
        }
    }

    [PSCustomObject]@{ Model = $model; Cmd = $null }
}

$view = {
    param($model)

    $titleStyle    = New-ElmStyle -Foreground 'BrightCyan' -Bold
    $questionStyle = New-ElmStyle -Foreground 'BrightWhite'
    $selectedStyle = New-ElmStyle -Foreground 'BrightYellow' -Bold
    $normalStyle   = New-ElmStyle -Foreground 'White'
    $correctStyle  = New-ElmStyle -Foreground 'BrightGreen'
    $wrongStyle    = New-ElmStyle -Foreground 'BrightRed'
    $hintStyle     = New-ElmStyle -Foreground 'BrightBlack'
    $boxStyle      = New-ElmStyle -Border 'Rounded' -Padding @(0, 2) -Width 56

    if ($model.Phase -eq 'Results') {
        $answers = @($model.Answers)
        $score   = ($answers | Where-Object { $_ }).Count
        $total   = $answers.Count

        $children = @(
            New-ElmText -Content 'Quiz Results' -Style $titleStyle
            New-ElmText -Content ''
            New-ElmText -Content "Score: $score / $total" -Style $questionStyle
            New-ElmText -Content ''
        )

        $qs = @($model.Questions)
        for ($i = 0; $i -lt $qs.Count; $i++) {
            $marker = if ($answers[$i]) { '[+]' } else { '[x]' }
            $style  = if ($answers[$i]) { $correctStyle } else { $wrongStyle }
            $children += New-ElmText -Content "$marker $($qs[$i].Text)" -Style $style
        }

        $children += New-ElmText -Content ''
        $children += New-ElmText -Content '[R] try again  [Q] quit' -Style $hintStyle

        return New-ElmBox -Style $boxStyle -Children $children
    }

    # Quiz phase
    $q      = $model.Questions[$model.QuestionIndex]
    $qNum   = $model.QuestionIndex + 1
    $qTotal = @($model.Questions).Count
    $opts   = @($q.Options)

    $children = @(
        New-ElmText -Content "Question $qNum of $qTotal" -Style $hintStyle
        New-ElmText -Content ''
        New-ElmText -Content $q.Text -Style $questionStyle
        New-ElmText -Content ''
    )

    for ($i = 0; $i -lt $opts.Count; $i++) {
        $marker = if ($i -eq $model.Selected) { '(*) ' } else { '( ) ' }
        $style  = if ($i -eq $model.Selected) { $selectedStyle } else { $normalStyle }
        $children += New-ElmText -Content "$marker$($opts[$i])" -Style $style
    }

    $children += New-ElmText -Content ''
    $children += New-ElmText -Content '[Up/Down] select  [Enter] confirm  [Q] quit' -Style $hintStyle

    New-ElmBox -Style $boxStyle -Children $children
}

Start-ElmProgram -InitFn $init -UpdateFn $update -ViewFn $view

if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../PSTea.psd1" }

# ---------------------------------------------------------------------------
# Quiz demo
# Five PowerShell/TEA multiple-choice questions.
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
        Text    = 'What does Compare-TeaViewTree return on the very first render?'
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

    $titleStyle    = New-TeaStyle -Foreground 'BrightCyan' -Bold
    $questionStyle = New-TeaStyle -Foreground 'BrightWhite'
    $selectedStyle = New-TeaStyle -Foreground 'BrightYellow' -Bold
    $normalStyle   = New-TeaStyle -Foreground 'White'
    $correctStyle  = New-TeaStyle -Foreground 'BrightGreen'
    $wrongStyle    = New-TeaStyle -Foreground 'BrightRed'
    $hintStyle     = New-TeaStyle -Foreground 'BrightBlack'
    $boxStyle      = New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 56

    if ($model.Phase -eq 'Results') {
        $answers = @($model.Answers)
        $score   = ($answers | Where-Object { $_ }).Count
        $total   = $answers.Count

        $children = @(
            New-TeaText -Content 'Quiz Results' -Style $titleStyle
            New-TeaText -Content ''
            New-TeaText -Content "Score: $score / $total" -Style $questionStyle
            New-TeaText -Content ''
        )

        $qs = @($model.Questions)
        for ($i = 0; $i -lt $qs.Count; $i++) {
            $marker = if ($answers[$i]) { '[+]' } else { '[x]' }
            $style  = if ($answers[$i]) { $correctStyle } else { $wrongStyle }
            $children += New-TeaText -Content "$marker $($qs[$i].Text)" -Style $style
        }

        $children += New-TeaText -Content ''
        $children += New-TeaText -Content '[R] try again  [Q] quit' -Style $hintStyle

        return New-TeaBox -Style $boxStyle -Children $children
    }

    # Quiz phase
    $q      = $model.Questions[$model.QuestionIndex]
    $qNum   = $model.QuestionIndex + 1
    $qTotal = @($model.Questions).Count
    $opts   = @($q.Options)

    $children = @(
        New-TeaText -Content "Question $qNum of $qTotal" -Style $hintStyle
        New-TeaText -Content ''
        New-TeaText -Content $q.Text -Style $questionStyle
        New-TeaText -Content ''
    )

    for ($i = 0; $i -lt $opts.Count; $i++) {
        $marker = if ($i -eq $model.Selected) { '(*) ' } else { '( ) ' }
        $style  = if ($i -eq $model.Selected) { $selectedStyle } else { $normalStyle }
        $children += New-TeaText -Content "$marker$($opts[$i])" -Style $style
    }

    $children += New-TeaText -Content ''
    $children += New-TeaText -Content '[Up/Down] select  [Enter] confirm  [Q] quit' -Style $hintStyle

    New-TeaBox -Style $boxStyle -Children $children
}

Start-TeaProgram -InitFn $init -UpdateFn $update -ViewFn $view

# A-03 — Timer-Driven UIs

**Track:** Advanced | **Prereqs:** A-01, A-02

---

## Objectives

By the end of this lesson you will be able to:

- Drive continuous UI updates from a timer subscription
- Use a `Running` flag to pause/resume a timer without losing accumulated state
- Combine a live clock (`[datetime]::Now`) with a spinner animation in a single Tick
- Apply `New-TeaSpinner` at different intervals by adjusting `IntervalMs`
- Use conditional View rendering to show paused/running states clearly

---

## Concept

### When to use timer-driven UIs

Use a timer subscription when:
- State needs to advance automatically (clocks, countdowns, progress simulations)
- You want animated feedback (spinners, progress bars that fill on their own)
- Polling an external value (a file, environment variable, process status)

A timer subscription fires at a fixed interval regardless of user input. The
event loop calls your `SubscriptionFn` after every model update — if the timer
sub is in the returned array, it remains active.

### Live clock pattern

```powershell
$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )
    if ($model.Running) {
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
    }
    $subs
}

$updateFn = {
    param($msg, $model)
    switch ($msg) {
        'Tick' {
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{
                    Running    = $model.Running
                    Frame      = $model.Frame + 1
                    ClockText  = [datetime]::Now.ToString('HH:mm:ss')
                }
                Cmd = $null
            }
        }
        ...
    }
}
```

`[datetime]::Now.ToString('HH:mm:ss')` captures the time at the moment of the Tick.
Store it as a string in the model — View just reads it.

### Fast vs slow ticks

You can use a fast timer (e.g., 100ms) for spinner animation while the clock only
changes once per second:

```powershell
New-TeaTimerSub -IntervalMs 100 -Handler { 'Frame' }   # spinner
New-TeaTimerSub -IntervalMs 1000 -Handler { 'Clock' }  # clock text
```

Both can coexist in the same subscription array.

Alternatively, use a single fast timer and update the clock conditionally:

```powershell
'Tick' {
    $newFrame = $model.Frame + 1
    # Update clock text only when the second changes
    $clockText = [datetime]::Now.ToString('HH:mm:ss')
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Running   = $model.Running
            Frame     = $newFrame
            ClockText = $clockText
        }
        Cmd = $null
    }
}
```

Calling `[datetime]::Now` on every 100ms tick is cheap. The string only changes
once per second; PSTea's diff renderer will update only the changed text node.

### Resetting elapsed seconds

Add `ElapsedSeconds` to the model and increment it on `'Clock'` ticks:

```powershell
'Clock' {
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            ...
            ElapsedSeconds = $model.ElapsedSeconds + 1
            ClockText      = [datetime]::Now.ToString('HH:mm:ss')
        }
        Cmd = $null
    }
}
```

`R` key resets `ElapsedSeconds = 0` without stopping the clock.

---

## Code Walkthrough

The companion script shows a live `hh:mm:ss` clock plus an animated spinner.
Space toggles pause/resume. R resets the elapsed seconds counter.

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Running        = $true
            Frame          = 0
            ClockText      = [datetime]::Now.ToString('HH:mm:ss')
            ElapsedSeconds = 0
        }
        Cmd = $null
    }
}
```

Initial `Running = $true` means the clock starts immediately.

```powershell
$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'R'        -Handler { 'ResetSeconds' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )
    if ($model.Running) {
        # Fast timer for spinner animation
        $subs += New-TeaTimerSub -IntervalMs 80   -Handler { 'Frame' }
        # Slow timer for clock text
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Clock' }
    }
    $subs
}
```

Two separate timer intervals — both pause together when `Running` is `$false`.

In View:

```powershell
$viewFn = {
    param($model)
    $hintStyle    = New-TeaStyle -Foreground 'BrightBlack'
    $clockStyle   = New-TeaStyle -Foreground 'BrightWhite' -Bold
    $spinnerStyle = New-TeaStyle -Foreground 'BrightCyan'

    $statusText  = if ($model.Running) { 'Running' } else { 'Paused' }
    $statusColor = if ($model.Running) { 'BrightGreen' } else { 'BrightYellow' }
    $spaceHint   = if ($model.Running) { '[Space] pause' } else { '[Space] resume' }

    New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Padding @(0, 2) -Width 32) -Children @(
        New-TeaRow -Children @(
            New-TeaSpinner -Frame $model.Frame -Variant 'Braille' -Style $spinnerStyle
            New-TeaText    -Content "  $($model.ClockText)"       -Style $clockStyle
        )
        New-TeaText -Content "Elapsed: $($model.ElapsedSeconds)s"
        New-TeaText -Content $statusText -Style (New-TeaStyle -Foreground $statusColor)
        New-TeaText -Content ''
        New-TeaText -Content "$spaceHint  [R] reset  [Q] quit" -Style $hintStyle
    )
}
```

---

## Common Mistakes

### Clock updates out of sync with real seconds

If you increment `ElapsedSeconds` in the fast (80ms) `'Frame'` tick instead of
the slow `'Clock'` tick, it increments ~12 times per second.
Keep elapsed time logic in the `'Clock'` (1000ms) handler.

### Spinner jumps when paused

When you resume after a pause, the timer sub is added back. Because timer state is
keyed by `IntervalMs`, the interval clock resets when the sub is re-added. This is
expected behavior — the spinner simply continues from where it left off based on `Frame`.
If you want smooth resumption, consider always leaving the fast timer active and only
pausing the clock timer.

---

## Exercises

1. **Lap timer.** Add `New-TeaKeySub -Key 'L' -Handler { 'Lap' }`. In Update, push
   `$model.ElapsedSeconds` onto a `Laps` array. In View, show the last 5 laps with
   `New-TeaList`.

2. **Countdown variant.** Add `Countdown = 60` to the model. On each `'Clock'` tick,
   decrement it. When it reaches zero, set `Running = $false`. Show it in View with
   a `New-TeaProgressBar -Percent ([int]($model.Countdown / 60 * 100))`.

3. **Double speed.** Change the fast timer to `IntervalMs 40` and note how the spinner
   appears twice as fast. Change the slow timer to `IntervalMs 500` and see the clock
   update twice per second.

---

## Next Lesson

**[A-04 — Capstone: Task Manager](04-capstone-task-manager.md):** full CRUD task manager
with form editing, a progress bar, a spinner for async-style feedback, and a two-column
layout.

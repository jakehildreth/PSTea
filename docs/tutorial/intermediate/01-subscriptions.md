# I-01 — Subscriptions

**Track:** Intermediate | **Prereqs:** Beginner track complete

---

## Objectives

By the end of this lesson you will be able to:

- Explain the difference between the **legacy key path** and the **subscription path**
- Write a `SubscriptionFn` that returns an array of subscription descriptors
- Use `New-TeaKeySub` to bind specific keys to named messages
- Use `New-TeaTimerSub` to fire timer-driven messages at a fixed interval
- Conditionally include a timer subscription to implement pause/resume
- Handle string messages (not PSCustomObjects) in Update

---

## Prerequisites

> **Prior track:** Beginner track (B-01 through B-05)
>
> You must be comfortable with the MVU loop, `switch ($msg.Key)` in Update, and
> `Start-TeaProgram` before continuing.

---

## Concept

### Two Key-Handling Paths

PSTea supports two ways to handle user input.

**Legacy path (no `SubscriptionFn`):**  
Raw `KeyDown` events are forwarded directly to Update as `$msg`.
You switch on `$msg.Key` (a ConsoleKey string).
This is what you used throughout the Beginner track.

**Subscription path (`SubscriptionFn` provided):**  
You pass a `-SubscriptionFn` scriptblock to `Start-TeaProgram`.
The event loop calls it after every model change to get the current set of active
subscriptions. Each subscription fires independently and returns a **message value**
which Update receives.

```
SubscriptionFn($model) → @(sub1, sub2, ...)
```

Key subs fire when the user presses the matching key.
Timer subs fire when their interval elapses.

When a sub fires, its `-Handler` scriptblock runs. Whatever that scriptblock returns
is the message passed to Update.

### `New-TeaKeySub`

```powershell
New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
```

- `-Key` — the key string (same names as `$msg.Key` in the legacy path)
- `-Handler` — scriptblock that runs when the key fires; its return value is the message
- Letter keys are matched case-insensitively by default

Multiple key subs can coexist:

```powershell
@(
    New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    New-TeaKeySub -Key 'UpArrow'  -Handler { 'MoveUp' }
    New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
)
```

### `New-TeaTimerSub`

```powershell
New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
```

- `-IntervalMs` — fire interval in milliseconds
- `-Handler` — no parameters; return value is the message
- Timer state is keyed by `IntervalMs`. If the same interval appears in two consecutive
  `SubscriptionFn` evaluations, the clock is continuous.
- **Removing** a timer sub pauses it; **adding it back** resets the interval clock.

### Conditional subscriptions — pause/resume

The `SubscriptionFn` is called after every model change. This lets you include/exclude
subscriptions based on model state:

```powershell
$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )
    # Only add the timer when the clock is running
    if ($model.Running) {
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
    }
    $subs
}
```

When `Running` is `$false`, the timer sub is absent — no Tick messages fire.
When `Running` becomes `$true`, the timer sub appears — Tick starts firing.

### Messages are handler return values — not PSCustomObjects

In the legacy path, `$msg` is always a `PSCustomObject` with `.Key`.
In the subscription path, `$msg` is whatever your handler returned.

If your handler returns `'Tick'` (a string), `$msg` in Update is the string `'Tick'`:

```powershell
# Legacy path
switch ($msg.Key) { 'Q' { ... } }

# Subscription path — switch on $msg directly
switch ($msg) {
    'Tick'   { ... }
    'Toggle' { ... }
    'Quit'   { ... }
}
```

This is the most common mistake when switching from legacy to subscription path.
Do not write `switch ($msg.Key)` in subscription-path apps.

---

## Code Walkthrough

The companion script is a **10→0 countdown** with pause/resume.

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            TimeLeft = 10
            Running  = $false    # starts paused; Space to begin
        }
        Cmd = $null
    }
}
```

`Running` is the pause flag. Starting paused avoids an immediate Tick on launch.

```powershell
$subscriptionFn = {
    param($model)
    $subs = @(
        New-TeaKeySub -Key 'Spacebar' -Handler { 'Toggle' }
        New-TeaKeySub -Key 'R'        -Handler { 'Reset' }
        New-TeaKeySub -Key 'Q'        -Handler { 'Quit' }
    )
    if ($model.Running -and $model.TimeLeft -gt 0) {
        $subs += New-TeaTimerSub -IntervalMs 1000 -Handler { 'Tick' }
    }
    $subs
}
```

The timer sub is included only when the countdown is running AND has time left.
When `TimeLeft` reaches zero the timer is excluded — the countdown stops automatically.

```powershell
$updateFn = {
    param($msg, $model)
    switch ($msg) {
        'Tick' {
            $newTime = [Math]::Max(0, $model.TimeLeft - 1)
            return [PSCustomObject]@{
                Model = [PSCustomObject]@{ TimeLeft = $newTime; Running = $model.Running }
                Cmd   = $null
            }
        }
        'Toggle' { ... }    # flip Running
        'Reset'  { ... }    # TimeLeft = 10, Running = $false
        'Quit'   { ... }    # Cmd = Quit
        default  { return [PSCustomObject]@{ Model = $model; Cmd = $null } }
    }
}
```

Notice: `switch ($msg)` not `switch ($msg.Key)`.

---

## Common Mistakes

### `switch ($msg.Key)` in subscription-path Update

`$msg` is a string like `'Tick'` — it does not have a `.Key` property.
`$msg.Key` evaluates to `$null`, so nothing matches. **Always use `switch ($msg)` in
the subscription path.**

---

### Forgetting to pass `-SubscriptionFn`

If you define `$subscriptionFn` but forget to pass it:

```powershell
Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
# Wrong: -SubscriptionFn $subscriptionFn is missing
```

The app falls back to the legacy path. The timer never fires.

---

### Timer fires once then stops because `SubscriptionFn` does not re-add it

If your `SubscriptionFn` only returns the timer sub on the first call (e.g., based on
a flag that changes after Tick), the timer stops after one tick.
Check that the condition for including the timer sub remains `$true` across model updates.

---

## Exercises

1. **Start at 30.** Change `TimeLeft` initial value to 30 and the timer to
   `IntervalMs 500` (fires every half second, so it counts down every half second).

2. **Completed message.** When `TimeLeft` reaches zero in the View, display a
   `'Time is up!'` message in `BrightRed` instead of `'0'`.

3. **Pause + resume display.** Show `'[Space] pause'` when `Running` is `$true` and
   `'[Space] start'` when `$false`. The hint line should change dynamically.

---

## Next Lesson

**[I-02 — Lists and Navigation](02-lists-and-navigation.md):** combine `New-TeaList`
with UpArrow/DownArrow subscriptions to build a navigable menu.

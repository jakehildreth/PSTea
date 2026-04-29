# A-01 — Components

**Track:** Advanced | **Prereqs:** Intermediate track complete

---

## Objectives

By the end of this lesson you will be able to:

- Explain what a PSTea component is and when to use one
- Define a component with an Init model, an Update scriptblock, and a View scriptblock
- Embed a component in a parent's view tree with `New-TeaComponent`
- Route messages to a component using `New-TeaComponentMsg`
- Dispatch `ComponentMsg` in the parent's Update
- Compose multiple component instances side by side

---

## Concept

### What is a component?

A **component** is a self-contained sub-program with its own:
- Sub-model (a `PSCustomObject`)
- Update scriptblock `{ param($msg, $subModel) → $newSubModel }`
- View scriptblock `{ param($subModel) → ViewNode }`

Components are useful when the same logic + UI appears more than once (e.g., multiple
counters, multiple text inputs, multiple list panels). Instead of duplicating state
fields and Update branches, you define the component once and instantiate it N times.

### Differences from the root program

| | Root program | Component |
|---|---|---|
| Init return | `{ Model = ...; Cmd = ... }` | Sub-model only (no Cmd wrapper) |
| Update return | `{ Model = ...; Cmd = ... }` | New sub-model only |
| View return | `ViewNode` | `ViewNode` |
| Subscription | `SubscriptionFn` param | No separate subscription system |

Components do **not** have their own subscriptions. The parent handles subscriptions
and routes messages to the component via `New-TeaComponentMsg`.

### Defining a component

```powershell
$counterComponent = @{
    Init = {
        [PSCustomObject]@{ Count = 0; Active = $false }
    }
    Update = {
        param($msg, $subModel)
        switch ($msg) {
            'Increment' { [PSCustomObject]@{ Count = $subModel.Count + 1; Active = $subModel.Active } }
            'Decrement' { [PSCustomObject]@{ Count = $subModel.Count - 1; Active = $subModel.Active } }
            'Activate'  { [PSCustomObject]@{ Count = $subModel.Count;     Active = $true  } }
            'Deactivate'{ [PSCustomObject]@{ Count = $subModel.Count;     Active = $false } }
            default     { $subModel }
        }
    }
    View = {
        param($subModel)
        $borderColor = if ($subModel.Active) { 'BrightCyan' } else { 'BrightBlack' }
        New-TeaBox -Style (New-TeaStyle -Border 'Rounded' -Width 18 -Foreground $borderColor) -Children @(
            New-TeaText -Content "Count: $($subModel.Count)"
        )
    }
}
```

Note that component Update returns the **sub-model directly** — no `@{ Model = ...; Cmd = ... }` wrapper.

### Embedding in a parent view tree

```powershell
$viewFn = {
    param($model)
    New-TeaRow -Children @(
        New-TeaComponent -ComponentId 'left'  -SubModel $model.Left  -ViewFn $using:counterComponent.View
        New-TeaComponent -ComponentId 'right' -SubModel $model.Right -ViewFn $using:counterComponent.View
    )
}
```

`New-TeaComponent` is a view node that PSTea expands automatically during rendering.
`ComponentId` must be unique per component instance.

### Routing messages from parent to component

The parent's Update receives all messages. To send a message to a specific component,
wrap it with `New-TeaComponentMsg`:

```powershell
# In SubscriptionFn:
New-TeaKeySub -Key 'UpArrow' -Handler {
    New-TeaComponentMsg -ComponentId 'left' -Msg 'Increment'
}
```

In the parent's Update:

```powershell
$updateFn = {
    param($msg, $model)

    # Route ComponentMsg to the right component
    if ($msg.Type -eq 'ComponentMsg') {
        $id      = $msg.ComponentId
        $innerMsg = $msg.Msg

        $newLeft  = $model.Left
        $newRight = $model.Right

        if ($id -eq 'left') {
            $newLeft  = & $using:counterComponent.Update $innerMsg $model.Left
        }
        if ($id -eq 'right') {
            $newRight = & $using:counterComponent.Update $innerMsg $model.Right
        }

        return [PSCustomObject]@{
            Model = [PSCustomObject]@{
                Left   = $newLeft
                Right  = $newRight
                Active = $model.Active
            }
            Cmd = $null
        }
    }

    # ... global messages
}
```

`& $scriptblock $arg1 $arg2` invokes a scriptblock stored in a variable.

### Tab-based focus between component instances

```powershell
$subscriptionFn = {
    param($model)
    $active = $model.Active   # 'left' or 'right'
    @(
        New-TeaKeySub -Key 'Tab' -Handler { 'SwitchFocus' }
        New-TeaKeySub -Key 'UpArrow' -Handler {
            New-TeaComponentMsg -ComponentId $using:active -Msg 'Increment'
        }
        New-TeaKeySub -Key 'DownArrow' -Handler {
            New-TeaComponentMsg -ComponentId $using:active -Msg 'Decrement'
        }
        New-TeaKeySub -Key 'Q' -Handler { 'Quit' }
    )
}
```

---

## Code Walkthrough

The companion script has two counters side by side. Tab moves focus between them.
The focused counter's border is bright; the unfocused one is dimmed.

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Left   = [PSCustomObject]@{ Count = 0; Active = $true  }
            Right  = [PSCustomObject]@{ Count = 0; Active = $false }
            Active = 'left'   # which counter has focus
        }
        Cmd = $null
    }
}
```

The parent model has two sub-models (`Left` and `Right`) and an `Active` string
indicating which one has focus.

`SwitchFocus` in Update:

```powershell
'SwitchFocus' {
    $nextActive = if ($model.Active -eq 'left') { 'right' } else { 'left' }
    return [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Left   = & $using:counterComponent.Update 'Deactivate' $model.Left  | Select-Object -First 1
            Right  = & $using:counterComponent.Update 'Deactivate' $model.Right | Select-Object -First 1
            Active = $nextActive
        } | ForEach-Object {
            # Activate the newly focused one
            if ($nextActive -eq 'left') {
                $_.Left = & $using:counterComponent.Update 'Activate' $_.Left | Select-Object -First 1
            } else {
                $_.Right = & $using:counterComponent.Update 'Activate' $_.Right | Select-Object -First 1
            }
            $_
        }
        Cmd = $null
    }
}
```

See the companion `.ps1` for a cleaner version using inline construction.

---

## Common Mistakes

### Component Update wraps in `{ Model; Cmd }`

**Wrong:**
```powershell
$counterComponent.Update = {
    param($msg, $subModel)
    # Returns { Model; Cmd } wrapper — incorrect for components
    [PSCustomObject]@{ Model = [PSCustomObject]@{ Count = $subModel.Count + 1 }; Cmd = $null }
}
```

**Right:** Component Update returns the sub-model directly:
```powershell
    [PSCustomObject]@{ Count = $subModel.Count + 1; Active = $subModel.Active }
```

### Forgetting `$using:` for component scriptblocks

Component scriptblocks captured in a parent that runs in a runspace need `$using:`:

```powershell
$viewFn = {
    param($model)
    New-TeaComponent -ComponentId 'c' -SubModel $model.Sub -ViewFn $using:myComponent.View
    #                                                               ^^^^^^
}
```

---

## Exercises

1. **Three counters.** Add a third `Center` counter. Tab cycles left → center → right → left.

2. **Reset.** Add `New-TeaKeySub -Key 'R' -Handler { New-TeaComponentMsg -ComponentId $using:active -Msg 'Reset' }`.
   Add a `'Reset'` branch to the component Update that sets `Count = 0`.

3. **Component totals.** In View, show the sum of all counter values in a row below the
   component row: `New-TeaText -Content "Total: $($model.Left.Count + $model.Right.Count)"`.

---

## Next Lesson

**[A-02 — Power Widgets](02-power-widgets.md):** tour of `New-TeaProgressBar`,
`New-TeaSpinner`, `New-TeaTable`, `New-TeaViewport`, `New-TeaTextarea`, and
`New-TeaPaginator` in a tabbed showcase.

# B-01 — MVU Architecture

## Objectives

By the end of this lesson you will be able to:

- Describe what the Model-View-Update pattern is and why it exists
- Explain the role of Init, Update, and View in a PSTea program
- Draw the data-flow cycle from key press to screen update
- Identify what `$msg`, `$model`, and `Cmd` are
- Explain why Update must be pure (no side effects)

---

## Prerequisites

> **No prior TUI or framework experience required.**
> You need: basic PowerShell — variables, hashtables, scriptblocks (`{ ... }`),
> and PSCustomObjects (`[PSCustomObject]@{ ... }`).
> No PSTea-specific knowledge assumed.

---

## Concept

### The problem: mutable shared state

Traditional interactive terminal apps accumulate state in variables scattered across
functions. When a keypress fires, several things need to update — and it is easy for
them to get out of sync. Tracking down the bug means understanding which function
last touched which variable.

**MVU solves this with a single rule:** there is exactly one place where state lives
(the **model**), and it can only change in one place (the **update** function).

### The three layers

PSTea implements **The Elm Architecture (TEA)**, also known as
**Model-View-Update (MVU)**. Every PSTea program consists of exactly three scriptblocks:

---

#### Init

```
() -> { Model; Cmd }
```

Called once when the program starts. Returns a `PSCustomObject` with two properties:

- `Model` — the initial state of your application. This can be any `PSCustomObject`.
- `Cmd` — an optional command. For Init, this is almost always `$null`.

```powershell
$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Count = 0 }
        Cmd   = $null
    }
}
```

Think of Init as answering: _"What does my app look like before the user does anything?"_

---

#### Update

```
($msg, $model) -> { Model; Cmd }
```

Called every time something happens (a key is pressed, a timer fires, etc.).
Receives the **message** and the **current model**. Returns a **new model** and an
optional **command**.

```powershell
$updateFn = {
    param($msg, $model)
    # examine $msg, produce a new model
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Count = $model.Count + 1 }
        Cmd   = $null
    }
}
```

**Update must be pure.** That means:
- No `Write-Host`, `Write-Output`, file writes, or network calls
- No mutations of `$model` in place
- Always returns a new `PSCustomObject` for `Model`

Update answers: _"Given what just happened, what should the state be now?"_

---

#### View

```
($model) -> view tree
```

Called after every Update. Receives the current model. Returns a **view tree** —
a nested structure of `New-TeaText` and `New-TeaBox` nodes that describes what the
terminal should display.

```powershell
$viewFn = {
    param($model)
    New-TeaText -Content "Count: $($model.Count)"
}
```

**View must also be pure.** It only reads from the model — no side effects, no state.

View answers: _"Given the current state, what should the screen show?"_

---

### The data-flow cycle

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                         PSTea Event Loop                        │
 │                                                                 │
 │  ┌──────────┐   key press   ┌────────────┐                     │
 │  │  Driver  │ ─────────────▶│ InputQueue │                     │
 │  └──────────┘               └─────┬──────┘                     │
 │                                   │ $msg                        │
 │                                   ▼                             │
 │  ┌────────────────────────────────────────┐                     │
 │  │  Update($msg, $model)  →  new $model   │                     │
 │  └──────────────────────┬─────────────────┘                     │
 │                         │ new $model                            │
 │                         ▼                                       │
 │  ┌────────────────────────────────────────┐                     │
 │  │  View($model)  →  view tree            │                     │
 │  └──────────────────────┬─────────────────┘                     │
 │                         │ view tree                             │
 │                         ▼                                       │
 │  ┌────────────────────────────────────────┐                     │
 │  │  Diff old tree vs new tree             │                     │
 │  │  Write ANSI output for changed cells   │                     │
 │  └────────────────────────────────────────┘                     │
 │                         │ back to waiting for next key          │
 └─────────────────────────┘                                       │
```

PSTea runs this loop continuously until Update returns a `Quit` command.

---

### What is `$msg`?

In the simplest case (the **legacy key path**, no `SubscriptionFn`), `$msg` is a
`PSCustomObject` produced by the terminal driver when a key is pressed:

```
$msg.Type      = 'KeyDown'
$msg.Key       = 'UpArrow'   # string matching .NET ConsoleKey enum name
$msg.Char      = [char]0     # the typed character (useful for text input)
$msg.Modifiers = 0           # Shift, Ctrl, Alt flags
```

Common `.Key` values: `'UpArrow'`, `'DownArrow'`, `'LeftArrow'`, `'RightArrow'`,
`'Enter'`, `'Backspace'`, `'Escape'`, `'Tab'`, `'Spacebar'`, `'Q'`, `'A'`, `'D3'`.

---

### What is `Cmd`?

A `Cmd` is a signal from your Update function to the PSTea framework. Right now,
there is essentially one useful command:

```powershell
[PSCustomObject]@{ Type = 'Quit' }
```

Returning this from Update tells PSTea to stop the event loop, tear down the terminal
driver, restore the cursor, and return the final model. For everything else, return
`$null` as the `Cmd`.

---

### How PSTea maps to the three layers

```powershell
Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
```

That is the entire framework entry point. `Start-TeaProgram`:

1. Calls `$initFn` to get the initial model
2. Sets up the terminal driver (alt screen, cursor hiding, key reader)
3. Runs the event loop until a `Quit` Cmd is returned
4. Tears down the driver and returns the final model

---

## Common Mistakes

### "Can I call Write-Host inside Update?"

**Wrong:**
```powershell
$updateFn = {
    param($msg, $model)
    Write-Host "debug: $($msg.Key)"   # side effect in Update!
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

**Right:** Update must be pure. Debug output will corrupt the terminal display.
Log to a file, or add a `DebugLog` field to the model and render it in View.

---

### "Does View only run when something changes?"

**Misconception:** "View is expensive, so I should cache it."

**Reality:** View is called on every message, but PSTea diffs the resulting tree
against the previous one and only redraws cells that changed. View should be fast
(no I/O, no computation beyond formatting strings) — then the diff cost is negligible.

---

### "Why do I need to return a whole new model object?"

**Wrong:**
```powershell
$updateFn = {
    param($msg, $model)
    $model.Count++   # mutating the model in place
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

**Right:**
```powershell
$updateFn = {
    param($msg, $model)
    [PSCustomObject]@{
        Model = [PSCustomObject]@{ Count = $model.Count + 1 }
        Cmd   = $null
    }
}
```

PSTea deep-copies the model before passing it to Update, so mutations technically
affect only the copy. But constructing a new object is the idiomatic pattern — it
makes your intent explicit, forces you to name every field you carry forward, and
prevents bugs where you accidentally keep stale state from a previous shape of the model.

---

## Next Lesson

**[B-02 — Hello, PSTea](02-hello-pstea.md):** write your first running PSTea program —
a static display with a working quit handler.

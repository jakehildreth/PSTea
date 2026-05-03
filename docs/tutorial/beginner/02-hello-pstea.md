# B-02 — Hello, PSTea

## Objectives

By the end of this lesson you will be able to:

- Import the PSTea module and call `Start-TeaProgram`
- Use `New-TeaText` and `New-TeaBox` to build a static view
- Write an Update function that handles the Quit key
- Understand what happens at exit (alt screen, cursor, final model)
- Know why forgetting to handle Q is dangerous

---

## Prerequisites

> **Prior lesson:** [B-01 — MVU Architecture](01-mvu-architecture.md) (or equivalent
> understanding of Init / Update / View).
>
> **PowerShell knowledge:** PSCustomObject, scriptblocks (`{ }`), basic functions.

---

## Concept

### Installing the Module
#### PowerShell Gallery

```powershell
Install-Module -Name PSTea -Scope CurrentUser -Force
```

#### GitHub

```powershell
git clone https://github.com/jakehildreth/PSTea
cd PSTea
Import-Module ./PSTea.psd1 -Force
```

### `Start-TeaProgram` — the only entry point

```powershell
Start-TeaProgram -InitFn $initFn -UpdateFn $updateFn -ViewFn $viewFn
```

Three mandatory parameters:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `-InitFn` | scriptblock | Returns `{ Model; Cmd }`. Called once. |
| `-UpdateFn` | scriptblock | `param($msg, $model)` → returns `{ Model; Cmd }` |
| `-ViewFn` | scriptblock | `param($model)` → returns a view node |

Optional parameters covered in later lessons: `-Width`, `-Height`, `-SubscriptionFn`,
`-TickMs`.

`Start-TeaProgram` returns the **final model** when the loop exits. This means your
app can produce output even from a TUI — just store results in the model and read them
after the call returns.

### View building blocks

#### `New-TeaText`

The leaf node. Everything visible in a PSTea app eventually becomes text.

```powershell
New-TeaText -Content 'Hello, world!'
```

Parameters: `-Content [string]` (mandatory), `-Style` (optional, covered in B-04).

#### `New-TeaBox`

A **vertical stack** of children. The most common container.

```powershell
New-TeaBox -Children @(
    New-TeaText -Content 'Line one'
    New-TeaText -Content 'Line two'
    New-TeaText -Content 'Line three'
)
```

Parameters: `-Children [object[]]` (mandatory), `-Style` (optional).

Children are stacked top-to-bottom. For side-by-side columns, use `New-TeaRow`
(covered in B-04).

### The Quit pattern

The **only** clean way to exit is to return a `Quit` command from Update:

```powershell
$updateFn = {
    param($msg, $model)
    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{
            Model = $model
            Cmd   = [PSCustomObject]@{ Type = 'Quit' }
        }
    }
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

When `Start-TeaProgram` sees `Cmd.Type -eq 'Quit'`:
1. The event loop exits
2. The terminal driver restores the cursor
3. The alt screen buffer is dismissed (terminal content reappears)
4. The console encoding is restored
5. `Start-TeaProgram` returns the final model

### What happens if you forget Quit?

The app runs forever. Ctrl+C may kill the process without restoring the terminal,
leaving the cursor hidden and the alt screen active. The shell prompt may disappear.
**Always handle at least one quit key.**

---

## Code Walkthrough

The companion script (`02-hello-pstea.ps1`) builds a static display with three info lines:

```powershell
# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Message : the text to display
# ---------------------------------------------------------------------------

$initFn = {
    [PSCustomObject]@{
        Model = [PSCustomObject]@{
            Message = 'Hello, PSTea!'
            Version = '1.0'
            Author  = 'You'
        }
        Cmd = $null
    }
}
```

Init defines the model shape. These three fields are everything View needs.

```powershell
# ---------------------------------------------------------------------------
# UPDATE
# ---------------------------------------------------------------------------

$updateFn = {
    param($msg, $model)
    # NOTE: $msg.Key is a string matching the .NET ConsoleKey enum name.
    # 'Q' matches the Q key regardless of Shift state.
    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{
            Model = $model
            Cmd   = [PSCustomObject]@{ Type = 'Quit' }
        }
    }
    [PSCustomObject]@{ Model = $model; Cmd = $null }
}
```

This is the minimum useful Update: handle Q, ignore everything else.

```powershell
# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------

$viewFn = {
    param($model)
    New-TeaBox -Children @(
        New-TeaText -Content $model.Message
        New-TeaText -Content "Version: $($model.Version)"
        New-TeaText -Content "Author:  $($model.Author)"
        New-TeaText -Content ''
        New-TeaText -Content '[Q] quit'
    )
}
```

Note `$($model.Version)` — PS string interpolation requires `$()` around property
access inside double-quoted strings.

---

## Common Mistakes

### Forgetting `Cmd = $null` on the passthrough branch

**Wrong:**
```powershell
$updateFn = {
    param($msg, $model)
    if ($msg.Key -eq 'Q') {
        return [PSCustomObject]@{ Model = $model; Cmd = [PSCustomObject]@{ Type = 'Quit' } }
    }
    # falling off the end — returns nothing (null)
}
```

**Right:** Always explicitly return `{ Model = $model; Cmd = $null }` from every branch.
Returning `$null` from Update will cause an error in the event loop.

---

### Using single quotes in string interpolation

**Wrong:**
```powershell
New-TeaText -Content 'Hello $($model.Name)'   # literal string, no interpolation
```

**Right:**
```powershell
New-TeaText -Content "Hello $($model.Name)"   # double quotes enable interpolation
```

---

### Calling Start-TeaProgram without importing the module

**Wrong:** Running the script from a shell that hasn't loaded PSTea.

**Right:** Each tutorial script starts with:
```powershell
if (-not (Get-Module PSTea)) { Import-Module "$PSScriptRoot/../../../PSTea.psd1" }
```

---

## Exercises

1. **Add a field.** Add a `Tagline` property to the model (e.g., `'Press Q to quit'`)
   and display it in View.

2. **Add a second quit key.** Make both `Q` and `Escape` trigger Quit. Check
   `$msg.Key -eq 'Escape'`.

3. **Use the return value.** After `Start-TeaProgram` returns, add a `Write-Host` call
   that prints the final model's `Message` field to the terminal. (Note: you'll be back
   on the normal screen by then, so `Write-Host` is fine here.)

---

## Next Lesson

**[B-03 — Increment/Decrement](03-increment-decrement.md):** make the app interactive —
messages, the switch pattern, and why the model must be reconstructed rather than mutated.

# PSTea Tutorial - A Work in Progress

A multi-track curriculum for building terminal user interfaces with the **PSTea** PowerShell
framework. PSTea implements the **Model-View-Update (MVU)** architecture — the same pattern
used by Elm, SwiftUI, and The Elm Architecture (TEA) — in pure PowerShell.

---

## Installation

Clone the repo and import the module. All tutorial scripts self-import from their own path:

```powershell
git clone https://github.com/jakehildreth/PSTea.git
cd PSTea
Import-Module ./PSTea.psd1
```

To run any tutorial script directly:

```powershell
# from the repo root
pwsh docs/tutorial/beginner/02-hello-pstea.ps1
```

**Requirements:** PowerShell 5.1+ or PowerShell 7+. A terminal that supports ANSI escape
sequences (Windows Terminal, iTerm2, macOS Terminal.app, most Linux terminals).

---

## Which Track?

| Track | If you... | Start here |
|-------|-----------|-----------|
| **Beginner** | Know basic PS (variables, hashtables, scriptblocks). No TUI experience needed. | [beginner/01-mvu-architecture.md](beginner/01-mvu-architecture.md) |
| **Intermediate** | Completed Beginner OR know MVU conceptually and are comfortable with PS. | [intermediate/01-subscriptions.md](intermediate/01-subscriptions.md) |
| **Advanced** | Completed Intermediate. Comfortable with subscriptions and multi-field focus. | [advanced/01-components.md](advanced/01-components.md) |

The tracks are independent — you can enter at any level. Each lesson calls out its
prerequisites explicitly.

---

## Beginner Track

_Build up from zero to a styled, interactive counter app._

| # | Lesson | What You Build | Files |
|---|--------|----------------|-------|
| B-01 | [MVU Architecture](beginner/01-mvu-architecture.md) | Nothing — conceptual foundation | md only |
| B-02 | [Hello, PSTea](beginner/02-hello-pstea.md) | Static "hello world" that exits cleanly | [md](beginner/02-hello-pstea.md) [ps1](beginner/02-hello-pstea.ps1) |
| B-03 | [Increment/Decrement](beginner/03-increment-decrement.md) | First interactive app — up/down counter | [md](beginner/03-increment-decrement.md) [ps1](beginner/03-increment-decrement.ps1) |
| B-04 | [Styling and Layout](beginner/04-styling-and-layout.md) | Bordered panels, colors, side-by-side columns | [md](beginner/04-styling-and-layout.md) [ps1](beginner/04-styling-and-layout.ps1) |
| B-05 | [Capstone: Nameable Counter](beginner/05-capstone-nameable-counter.md) | Styled counter with rename, inc/dec, quit | [md](beginner/05-capstone-nameable-counter.md) [ps1](beginner/05-capstone-nameable-counter.ps1) |

---

## Intermediate Track

_Add subscriptions, live lists, text input, and a complete two-pane app._

| # | Lesson | What You Build | Files |
|---|--------|----------------|-------|
| I-01 | [Subscriptions](intermediate/01-subscriptions.md) | Countdown timer with pause/resume | [md](intermediate/01-subscriptions.md) [ps1](intermediate/01-subscriptions.ps1) |
| I-02 | [Lists and Navigation](intermediate/02-lists-and-navigation.md) | Scrollable color list with arrow-key nav | [md](intermediate/02-lists-and-navigation.md) [ps1](intermediate/02-lists-and-navigation.ps1) |
| I-03 | [Text Input](intermediate/03-text-input.md) | Live text field with cursor and all editing keys | [md](intermediate/03-text-input.md) [ps1](intermediate/03-text-input.ps1) |
| I-04 | [Focus and Forms](intermediate/04-focus-and-forms.md) | Two-field form with Tab focus and a checkbox | [md](intermediate/04-focus-and-forms.md) [ps1](intermediate/04-focus-and-forms.ps1) |
| I-05 | [Capstone: Note-Taker](intermediate/05-capstone-note-taker.md) | List + detail pane + add/delete — controls wired | [md](intermediate/05-capstone-note-taker.md) [ps1](intermediate/05-capstone-note-taker.ps1) |

---

## Advanced Track

_Components, power widgets, timers, and a full task manager._

| # | Lesson | What You Build | Files |
|---|--------|----------------|-------|
| A-01 | [Components](advanced/01-components.md) | Two reusable counters with parent focus routing | [md](advanced/01-components.md) [ps1](advanced/01-components.ps1) |
| A-02 | [Power Widgets](advanced/02-power-widgets.md) | Tabbed widget showcase (table, viewport, spinner…) | [md](advanced/02-power-widgets.md) [ps1](advanced/02-power-widgets.ps1) |
| A-03 | [Timer-Driven UIs](advanced/03-timer-driven-uis.md) | Live clock + spinner with pause/resume | [md](advanced/03-timer-driven-uis.md) [ps1](advanced/03-timer-driven-uis.ps1) |
| A-04 | [Capstone: Task Manager](advanced/04-capstone-task-manager.md) | Full app: list + edit form + checkbox + progress bar | [md](advanced/04-capstone-task-manager.md) [ps1](advanced/04-capstone-task-manager.ps1) |

---

## How to Read the Lesson Files

Each `.md` lesson follows a consistent structure:

1. **Objectives** — what you will be able to do when you finish
2. **Prerequisites** — what you need to know before starting
3. **Concept** — the idea explained in prose, with diagrams
4. **Code Walkthrough** — annotated snippets from the companion `.ps1`
5. **Common Mistakes** — specific gotchas with wrong vs right examples
6. **Exercises** — hands-on challenges you can tackle in the `.ps1`
7. **Next Lesson** — one-line preview and link

Capstone lessons contain three formats so you can pick your learning style:
- **Section A** — step-by-step build from scratch
- **Section B** — architecture walkthrough of the final app
- **Section C** — numbered steps with full copy-paste snippets

---

## Quick Reference: Key Strings

In the legacy key path (no `SubscriptionFn`), `$msg.Key` is a `[System.ConsoleKey]`
enum value. PowerShell coerces it to a string in `switch` and `-eq` comparisons, so
you can use string literals directly (e.g. `'UpArrow'`, `'Q'`). Common values:

| Key pressed | `$msg.Key` | `$msg.Char` |
|-------------|------------|-------------|
| Up arrow | `'UpArrow'` | — |
| Down arrow | `'DownArrow'` | — |
| Left arrow | `'LeftArrow'` | — |
| Right arrow | `'RightArrow'` | — |
| Enter | `'Enter'` | — |
| Backspace | `'Backspace'` | — |
| Delete | `'Delete'` | — |
| Escape | `'Escape'` | — |
| Tab | `'Tab'` | — |
| Space | `'Spacebar'` | `' '` |
| Letter Q | `'Q'` | `'q'` or `'Q'` |
| Digit 3 | `'D3'` | `'3'` |

For text input (inserting typed characters), use `$msg.Char`:

```powershell
if (-not [char]::IsControl($msg.Char)) {
    $newValue = $model.Value.Insert($model.CursorPos, [string]$msg.Char)
}
```

---

## Design Notes

- The web driver (`Start-TeaWebServer`) is not covered in this tutorial — it adds
  infrastructure complexity without teaching additional MVU concepts.
- PSTea does not have a built-in `New-TeaCheckbox` widget. The tutorial teaches the
  manual `[ ]/[x]` + Space pattern. A first-class widget is on the roadmap.

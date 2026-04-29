# PSTea Tutorial Curriculum — Design Plan

## Overview

Three-track curriculum for the PSTea PowerShell TUI framework. Each track is a
self-contained learning path. Learners can enter at any track level.

**Output:** `docs/tutorial/` — paired `.md` lesson files and runnable `.ps1` companion
scripts for each lesson.

---

## Tracks

| Track | Prerequisites | Lessons |
|-------|---------------|---------|
| Beginner | Basic PowerShell (variables, hashtables, scriptblocks) | 5 |
| Intermediate | Beginner track OR MVU familiarity + comfortable PS | 5 |
| Advanced | Intermediate track | 4 |

---

## Directory Layout

```
docs/tutorial/
  README.md                               (index, install, prereqs, quick-start)
  beginner/
    01-mvu-architecture.md                (markdown only — no .ps1)
    02-hello-pstea.md
    02-hello-pstea.ps1
    03-increment-decrement.md
    03-increment-decrement.ps1
    04-styling-and-layout.md
    04-styling-and-layout.ps1
    05-capstone-nameable-counter.md
    05-capstone-nameable-counter.ps1
  intermediate/
    01-subscriptions.md
    01-subscriptions.ps1
    02-lists-and-navigation.md
    02-lists-and-navigation.ps1
    03-text-input.md
    03-text-input.ps1
    04-focus-and-forms.md
    04-focus-and-forms.ps1
    05-capstone-note-taker.md
    05-capstone-note-taker.ps1
  advanced/
    01-components.md
    01-components.ps1
    02-power-widgets.md
    02-power-widgets.ps1
    03-timer-driven-uis.md
    03-timer-driven-uis.ps1
    04-capstone-task-manager.md
    04-capstone-task-manager.ps1
```

---

## Lesson Format

### Standard Lesson `.md` Template

Every non-capstone lesson uses this section order:

1. **Objectives** — 3–5 bullets: "by the end of this lesson you will be able to…"
2. **Prerequisites** — callout block: prior lessons and PS knowledge assumed
3. **Concept** — prose explanation with ASCII diagrams where helpful
4. **Code Walkthrough** — annotated code snippets (targeted excerpts, not the full .ps1)
5. **Common Mistakes** — 2–4 gotchas with "wrong" vs "right" examples
6. **Exercises** — 2–3 hands-on challenges modifying the .ps1
7. **Next Lesson** — one-line preview + link

### Capstone `.md` Template

Capstones contain all three formats so the learner can pick their style:

- **Section A: Step-by-Step Build** — starts from scratch, code grows incrementally
- **Section B: Architecture Walkthrough** — prose explanation of the final app's design
- **Section C: Numbered Steps with Full Snippets** — copy-paste-friendly, complete code blocks

### Companion `.ps1` Style

Hybrid: section header separators + `# NOTE:` inline comments for non-obvious decisions.
No essay prose. Standard section headers: `MODEL`, `INIT`, `UPDATE`, `VIEW`,
`SUBSCRIPTIONS`, `RUN`.

```powershell
# ---------------------------------------------------------------------------
# MODEL
# ---------------------------------------------------------------------------
# Count : current integer value (can go negative)
# ---------------------------------------------------------------------------
```

### Code Quality

Teaching-quality:
- OTBS braces, 4-space indent, straight quotes, descriptive variable names
- No `[CmdletBinding()]`, no `$PSCmdlet.WriteError()`, no `param()` on top-level scripts
- Clean and readable without advanced cmdlet plumbing

### Cross-Track References

Always explicit. When a lesson builds on an earlier lesson, call it out inline:
> "recall from B-03: Update always constructs a new model object rather than mutating the existing one"

---

## Lesson Breakdown

### BEGINNER TRACK

**B-01 — MVU Architecture** (markdown only)

The problem MVU solves → the three layers (Init / Update / View) defined precisely →
ASCII data-flow diagram → how PSTea maps to each layer → what Cmd and $msg are →
three pre-empted misconceptions (Write-Host in Update, View frequency, why new object).

---

**B-02 — Hello, PSTea**

`Start-TeaProgram` signature (3 mandatory params) → `New-TeaText` and `New-TeaBox` as the
two building blocks → static app with no interactivity → the Quit pattern in detail →
what happens at exit → gotcha: forgetting to handle Q.

*Demo:* static multi-line display, Q exits cleanly.

---

**B-03 — Increment/Decrement**

What `$msg.Key` is (ConsoleKey-as-string) → common key name strings → the
`switch ($msg.Key)` skeleton → immutability: why construct a new model instead of
mutating → always include a `default` branch → string interpolation in View.

*Demo:* UpArrow inc, DownArrow dec (can go negative), Q quit.

---

**B-04 — Styling and Layout**

`New-TeaStyle` params (Foreground, Background, Bold/Italic/Underline/Strikethrough,
Border, Padding, Margin*, Width) → named color list → `New-TeaBox` vs `New-TeaRow` →
how they compose into multi-column layouts → ASCII box-model diagram → gotcha: Width
constrains container, not content.

*Demo:* two-column layout, multiple border styles, padding vs margin comparison.

---

**B-05 — Capstone: Nameable Counter**

Complete styled app. Model: `{ Name; Count; Editing; NameDraft }`.
UpArrow/DownArrow increment/decrement. E enters edit-name mode (character append,
Backspace, Enter to confirm, Escape to cancel). Q guarded by `if (-not $model.Editing)`.
Conditional view rendering. Rounded border, BrightCyan/BrightWhite theme.

---

### INTERMEDIATE TRACK

**I-01 — Subscriptions**

Why subs over legacy path → `New-TeaKeySub -Key 'X' -Handler { 'Msg' }` (Handler
return IS the message) → `New-TeaTimerSub -IntervalMs N -Handler { 'Tick' }` →
`SubscriptionFn` param: `{ param($model) return @(...) }`, reactive to model →
conditional subs: timer sub absent when `$model.Running -eq $false` → messages from
subs are handler return values, not PSCustomObjects with .Key.

*Demo:* 10→0 countdown, Space start/pause, R reset, Q quit.

---

**I-02 — Lists and Navigation**

`New-TeaList` params (Items, SelectedIndex, MaxVisible, Prefix, UnselectedPrefix,
Style, SelectedStyle) → model pattern `{ Items; Cursor }` → wrapping cursor
arithmetic → accessing selected item → gotcha: Items must be strings.

*Demo:* 16 color names, UpArrow/DownArrow with wrap, selected item shown in its own
color, MaxVisible=8 so scrolling is visible.

---

**I-03 — Text Input and Cursor Management**

`New-TeaTextInput` params (Value, CursorPos, Focused, Placeholder, CursorChar, Style,
FocusedStyle, FocusedBoxStyle) → `$msg.Key` vs `$msg.Char` for text input → full
cursor movement update patterns (CharInput, Backspace, Delete, Left, Right, Home, End)
→ gotcha: PS strings are immutable, `.Insert()`/`.Remove()` return new strings.

*Demo:* single input field, all cursor keys, Backspace/Delete, live preview of typed
value, Enter submits, Q quits.

---

**I-04 — Focus and Forms**

Focus model pattern (`FocusedField = 'Name'` string) → Tab key cycles focus with wrap
→ conditional `-Focused` switch in View → routing char/cursor keys only to focused
field → the checkbox pattern (`[ ]/[x]` + Space to toggle — note: `New-TeaCheckbox`
widget is planned, manual pattern is idiomatic now) → Enter to submit with validation.

*Demo:* two-field form (Name text input + Subscribed checkbox), Tab cycles focus,
Space toggles checkbox, Enter submits and exits.

---

**I-05 — Capstone: Note-Taker**

Two-pane app. Model: `{ Notes; Cursor; Mode ('Browse'|'Adding'|'Editing'); Draft; DraftCursor }`.
Left: `New-TeaList` of note titles. Right: selected note detail.
A adds (text input for title, Enter to save, Escape to cancel).
D deletes (cursor wraps). E edits title. Q quits and returns notes array.
Key insight: `model.Mode` IS the state machine — same keys behave differently per mode.

---

### ADVANCED TRACK

**A-01 — Components**

Why components → convention: PSCustomObject with Init/Update/View scriptblocks →
`New-TeaComponent -ComponentId -SubModel -ViewFn` (transparent after layout) →
`New-TeaComponentMsg -ComponentId -Msg` → parent routing pattern (check
`$msg.Type -eq 'ComponentMsg'`, switch on ComponentId, call component Update, replace
sub-model) → component Update returns new sub-model only (no Cmd wrapper) → Tab
switches parent focus, only focused component receives key messages.

*Demo:* two independent counters side by side, Tab switches focus (border highlights),
UpArrow/DownArrow affect only the focused counter.

---

**A-02 — Power Widgets**

One section per widget with purpose, key params, rendered example, common gotcha:
`New-TeaProgressBar` (Value/Percent, Width includes brackets),
`New-TeaSpinner` (Frame model-owned, Variant, doesn't self-animate),
`New-TeaTable` (Headers, Rows as string arrays, SelectedRow, ColumnWidths auto-sizes),
`New-TeaViewport` (Lines, ScrollOffset manual — unlike List does NOT auto-scroll),
`New-TeaTextarea` (Lines string[], CursorRow/Col, same editing patterns as TextInput),
`New-TeaPaginator` (numeric/tabs/dots modes).

*Demo:* tabbed layout, one panel per widget, live controls, spinner animated via timer.

---

**A-03 — Timer-Driven UIs**

Two timer approaches: `TickMs` on `Start-TeaProgram` (always-on) vs `New-TeaTimerSub`
in SubscriptionFn (conditional, preferred for pause/resume) → handling 'Tick' in Update
→ Pomodoro pattern for pause/resume (sub absent when not running) → spinner animation
(`Frame += 1` on Tick) → gotcha: don't mix both approaches (double-tick).

*Demo:* live clock (hh:mm:ss), animated spinner, Space pause/resume, R reset seconds.

---

**A-04 — Capstone: Task Manager**

Full-featured app exercising every major concept from all three tracks.
Left panel (25%): `New-TeaList` of tasks (done items strikethrough).
Right panel (75%): editable title (TextInput) + description (TextInput) + `[ ] Done`
checkbox + overall `New-TeaProgressBar` + `New-TeaSpinner` save indicator.
Tab: List → Title → Description → Done → List.
N: new task. D: delete with double-press guard.
Enter/Tab auto-saves field when leaving. Escape cancels/reverts.
Q: only from List focus. Saving spinner: 500ms via conditional TimerSub.
Uses legacy key path + TickMs for smooth spinner animation while saving.

---

## Technical Notes

### Key Input in the Legacy Path

When `SubscriptionFn` is null, raw key events from the terminal driver go directly to
`UpdateFn` as `$msg`:

```
$msg.Type      = 'KeyDown'
$msg.Key       = [ConsoleKey] enum value (e.g., ConsoleKey.Q → 'Q', ConsoleKey.UpArrow → 'UpArrow')
$msg.Char      = actual typed char (e.g., 'a', 'A', '1') — use for text insertion
$msg.Modifiers = [ConsoleModifiers] (Shift, Ctrl, Alt flags)
```

For text input, use `$msg.Char` to detect printable characters:
```powershell
if (-not [char]::IsControl($msg.Char)) {
    $newValue = $model.Value.Insert($model.CursorPos, [string]$msg.Char)
}
```

### Subscription Path

When `SubscriptionFn` is provided, it becomes the SOLE queue consumer.
Use for timer-driven UIs or when you only need a fixed set of named key bindings.
Cannot easily handle arbitrary character input — use the legacy path for text fields.

For apps needing both timers AND character input, use the legacy path + `TickMs` on
`Start-TeaProgram`. Tick messages arrive as `$msg.Key -eq 'Tick'` in Update.

### Immutability

`Invoke-TeaUpdate` deep-copies the model before calling UpdateFn (via `Copy-TeaModel`).
Mutations to the copy are technically safe, but constructing a new PSCustomObject is
the idiomatic pattern — it makes intent explicit and prevents accidentally carrying
over stale state from unrelated fields.

---

## Format Decisions Summary

| Decision | Choice |
|----------|--------|
| Lesson .md template | Objectives → Prerequisites → Concept → Walkthrough → Mistakes → Exercises → Next |
| Capstone .md template | All three formats (build-up / architecture / numbered steps) |
| .ps1 style | Hybrid: section headers + `# NOTE:` comments, no essay prose |
| Code quality | Teaching-quality (readable, idiomatic, no cmdlet plumbing) |
| Cross-track refs | Always explicit (`"recall from B-03: ..."`) |
| README contents | Full (install, prereqs per track, quick-start, TOC) |
| Web driver scope | Excluded — adds complexity without teaching core concepts |
| Checkbox widget | Manual `[ ]/[x]` + Space pattern (New-TeaCheckbox widget is planned) |

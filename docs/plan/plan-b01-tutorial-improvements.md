# Plan: B-01 Tutorial Improvements

Source: tutorial walkthrough session with new user. Issues raised during review of
`docs/tutorial/beginner/01-mvu-architecture.md`.

---

## Changes

### 1. Strengthen `Cmd = $null` guidance

- Flip emphasis in "What is Cmd?" so `$null` is the primary case and `Quit` is the
  rare exception
- Explicitly contrast direction: `$msg` flows INTO your app (world → Update); `Cmd`
  flows OUT of your app (Update → framework) — they are opposites
- Add a common mistake entry: omitting `Cmd` from the return object causes a
  null-dereference deep in the event loop; both `Model` and `Cmd` must always be
  present in every return value

### 2. Remove elm-style type signatures

- The `() -> { Model; Cmd }`, `($msg, $model) -> { Model; Cmd }`, and
  `($model) -> view tree` code blocks in the Init, Update, and View sections are
  borrowed from Elm's type notation and are meaningless to PowerShell users — they
  look like scriptblocks with statements
- Replace each with a plain-english narrative sentence describing what the scriptblock
  receives and what it returns

### 3. Add "pure vs. side-effectful" section

The current "Update must be pure" note is a one-liner that doesn't give users enough
to categorize their own code. Add a dedicated section covering:

- Definition of "pure": same inputs always produce the same outputs, with no observable
  effect on the outside world
- Two categories with examples:
  - Data transformation (safe): math, string formatting, conditional logic, calling
    pure helper functions
  - Side effects (not safe): file i/o, network calls, `Write-Host`, reading the clock,
    randomness, mutating shared variables
- Practical self-test: "could I call this function twice in a row and get the same
  result both times, with nothing in the world changing?" — if yes, it's safe
- Why PSTea cares: Update runs synchronously on the event loop; a blocking call
  freezes the entire UI; a side effect can corrupt the terminal display or make state
  impossible to reason about
- Where side effects belong: subscriptions (timers, key events) and future Cmd handlers
- Native commands (`git`, `curl`, etc.) are almost always side-effectful AND blocking
  — a double no

### 4. Expand View section with examples

The View section currently shows only a single `New-TeaText` line. Add examples for:

- Rendering multiple model fields
- Conditional rendering based on model state (e.g. show different text depending on a
  boolean flag)
- Nesting: `New-TeaBox` wrapping multiple `New-TeaText` nodes

### 5. Fix the data-flow diagram

Two problems with the current ASCII diagram:

- The loop does not visually close — the arrow trails off instead of connecting back
  to the Driver/InputQueue
- Init is missing entirely — it should appear before the loop to show it runs once to
  produce the first `$model`, after which the loop takes over

Replace the ASCII art with a Mermaid flowchart that:

- Shows Init running once, feeding the initial `$model` into the loop
- Shows the closed cycle: Driver → InputQueue → Update → View → Diff/Render → Driver
- Adds a prose walkthrough below the diagram explaining what each node is and
  clarifying that user code only touches Update and View

### 6. Expand `$msg` examples

The current section shows the object shape but no examples of acting on it. Add
concrete code examples of switching on `$msg.Key` for:

- Arrow keys (navigation)
- Enter and Escape (confirm/cancel)
- A letter key (shortcut)
- `$msg.Char` for text input (character accumulation)
- A timer message (what it looks like when subscriptions fire)

### 7. Expand terminal driver explanation

The bullet "sets up the terminal driver (alt screen, cursor hiding, key reader)" papers
over a lot that will be confusing to new users. Replace with a brief plain-english
explanation of each piece:

- **Alt screen** — switches the terminal to a separate buffer so the app doesn't trash
  the user's shell history; the original screen is restored when the program exits
- **Cursor hiding** — hides the blinking cursor to prevent flicker during redraws
- **Raw mode** — bypasses terminal line-buffering so every keypress fires immediately
  and silently (no echo, no waiting for Enter)
- **Key reader** — a background runspace that sits in a loop calling
  `[Console]::ReadKey()` and pushing messages onto the input queue

Reassure the user that all of this is automatic and the terminal is fully restored
when the program exits normally.

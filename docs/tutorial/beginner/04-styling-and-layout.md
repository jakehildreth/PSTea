# B-04 — Styling and Layout

## Objectives

By the end of this lesson you will be able to:

- Create `New-TeaStyle` objects with color, weight, border, padding, and width
- Use the full named-color list
- Distinguish `New-TeaBox` (vertical) from `New-TeaRow` (horizontal)
- Compose nested boxes and rows into multi-column layouts
- Understand the padding vs margin box model

---

## Prerequisites

> **Prior lesson:** [B-03 — Increment/Decrement](03-increment-decrement.md)
>
> **Concepts needed:** `New-TeaText`, `New-TeaBox`, `Start-TeaProgram`. The `switch`
> pattern from B-03. If you have not completed B-03, read at least B-01 and B-02.

---

## Concept

### `New-TeaStyle` — the style value object

`New-TeaStyle` does not render anything itself. It creates a **value object** that you
pass to `-Style` on any view node. Think of it as a bundle of visual properties.

```powershell
$myStyle = New-TeaStyle -Foreground 'BrightCyan' -Bold -Border 'Rounded' -Padding @(0, 2)
New-TeaText -Content 'Hello!' -Style $myStyle
```

#### Color parameters

| Parameter | Type | What it controls |
|-----------|------|-----------------|
| `-Foreground` | string | Text (foreground) color |
| `-Background` | string | Cell background color |

Named colors (case-insensitive):

```
Black         Red           Green         Yellow
Blue          Magenta       Cyan          White
BrightBlack   BrightRed     BrightGreen   BrightYellow
BrightBlue    BrightMagenta BrightCyan    BrightWhite
```

`BrightBlack` renders as dark grey in most terminals. It is the standard choice for
hint text and secondary information.

#### Text decoration

All are switches (no value needed):

```powershell
New-TeaStyle -Bold
New-TeaStyle -Italic
New-TeaStyle -Underline
New-TeaStyle -Strikethrough
```

#### Border

```powershell
New-TeaStyle -Border 'None'     # default — no border
New-TeaStyle -Border 'Normal'   # +----- style (ASCII)
New-TeaStyle -Border 'Rounded'  # ╭───── style (Unicode)
New-TeaStyle -Border 'Thick'    # ┏━━━━━ style (Unicode)
New-TeaStyle -Border 'Double'   # ╔═════ style (Unicode)
```

Border is applied to `New-TeaBox` and `New-TeaRow` nodes. Adding a border to a
`New-TeaText` is possible but unusual.

#### Size and spacing

```powershell
New-TeaStyle -Width 40        # fixed width in columns (omit for auto-size)
```

**Padding** — space _inside_ the border:

```powershell
New-TeaStyle -Padding 1               # 1 on all sides
New-TeaStyle -Padding @(1, 2)         # 1 top/bottom, 2 left/right
New-TeaStyle -Padding @(1, 2, 1, 2)  # top, right, bottom, left
```

**Margin** — space _outside_ the border:

```powershell
New-TeaStyle -Margin 1
New-TeaStyle -MarginTop 1 -MarginRight 2 -MarginBottom 1 -MarginLeft 2
```

Visual box model:

```
  ┌── margin ──────────────────────────────┐
  │  ┌── border ──────────────────────────┐│
  │  │  ┌── padding ──────────────────┐  ││
  │  │  │   content                  │  ││
  │  │  └────────────────────────────┘  ││
  │  └────────────────────────────────────┘│
  └──────────────────────────────────────── ┘
```

### `New-TeaBox` — vertical stack

```powershell
New-TeaBox -Children @($child1, $child2, $child3) -Style $style
```

Children are arranged **top to bottom**. This is the default container for most layouts.

### `New-TeaRow` — horizontal stack

```powershell
New-TeaRow -Children @($leftPanel, $rightPanel) -Style $style
```

Children are arranged **left to right**. Use `New-TeaRow` whenever you want columns.

### Composing layouts

Nest boxes inside rows and vice versa to build complex layouts:

```powershell
# Two-column layout: left nav + right content
New-TeaRow -Children @(
    New-TeaBox -Style (New-TeaStyle -Width 20 -Border 'Rounded') -Children @(
        New-TeaText -Content 'Nav item 1'
        New-TeaText -Content 'Nav item 2'
    )
    New-TeaBox -Style (New-TeaStyle -Width 40 -Border 'Rounded') -Children @(
        New-TeaText -Content 'Content here'
    )
)
```

Produces:
```
╭──────────────────╮╭──────────────────────────────────────╮
│Nav item 1        ││Content here                          │
│Nav item 2        ││                                      │
╰──────────────────╯╰──────────────────────────────────────╯
```

### The `-Width` gotcha

`-Width` constrains the **container**, not the **content**. If a `New-TeaText` node has
content wider than the box's width, it will be clipped. Plan content to fit.

---

## Code Walkthrough

The companion script shows four different panels simultaneously:
a colored welcome panel, a border showcase, a padding/margin comparison, and a hint bar.

```powershell
$viewFn = {
    param($model)

    # Reusable styles defined at the top of View — not in the model
    $titleStyle   = New-TeaStyle -Foreground 'BrightCyan'  -Bold
    $bodyStyle    = New-TeaStyle -Foreground 'White'
    $dimStyle     = New-TeaStyle -Foreground 'BrightBlack'
```

Styles are created fresh in View on every render. This is intentional — View is a
pure function with no stored state.

```powershell
    # Left panel: color + style showcase
    $leftStyle  = New-TeaStyle -Border 'Rounded' -Padding @(1, 2) -Width 28
    $leftPanel  = New-TeaBox -Style $leftStyle -Children @(
        New-TeaText -Content 'Style showcase'      -Style $titleStyle
        New-TeaText -Content 'Normal text'         -Style $bodyStyle
        New-TeaText -Content 'Bold text'           -Style (New-TeaStyle -Bold)
        New-TeaText -Content 'Italic text'         -Style (New-TeaStyle -Italic)
        New-TeaText -Content 'Underline text'      -Style (New-TeaStyle -Underline)
        New-TeaText -Content 'Strikethrough text'  -Style (New-TeaStyle -Strikethrough)
        New-TeaText -Content 'BrightRed'           -Style (New-TeaStyle -Foreground 'BrightRed')
        New-TeaText -Content 'BrightGreen'         -Style (New-TeaStyle -Foreground 'BrightGreen')
        New-TeaText -Content 'BrightYellow'        -Style (New-TeaStyle -Foreground 'BrightYellow')
        New-TeaText -Content 'BrightBlue'          -Style (New-TeaStyle -Foreground 'BrightBlue')
        New-TeaText -Content 'BrightMagenta'       -Style (New-TeaStyle -Foreground 'BrightMagenta')
        New-TeaText -Content 'BrightCyan'          -Style (New-TeaStyle -Foreground 'BrightCyan')
    )
```

`New-TeaStyle` is created inline with `(...)` when you do not need to reuse the style.

```powershell
    # Right panel: border styles
    New-TeaRow -Children @($leftPanel, $borderPanel)
```

`New-TeaRow` places the left and right panels side by side.

---

## Common Mistakes

### Creating a style and applying it to the wrong node

**Wrong:**
```powershell
$boxStyle = New-TeaStyle -Border 'Rounded'
New-TeaText -Content 'Hello' -Style $boxStyle   # border on Text — unusual, rarely useful
```

**Right:** Apply border styles to `New-TeaBox` or `New-TeaRow`, not to `New-TeaText`.

---

### Forgetting `-Width` and getting a full-terminal-width box

**Scenario:** You have two boxes in a `New-TeaRow` but the second one wraps to the next
line because the first fills the terminal width.

**Fix:** Set explicit `-Width` on both box styles:
```powershell
New-TeaStyle -Border 'Rounded' -Width 30   # left panel
New-TeaStyle -Border 'Rounded' -Width 40   # right panel
```

---

### Confusing padding and margin

- **Padding** goes _inside_ the border — adds space between the border and the content.
- **Margin** goes _outside_ the border — adds space between this node and adjacent nodes.

If your content looks crowded _inside_ the box, increase padding.  
If boxes are too close together, increase margin (or `MarginRight`/`MarginLeft`).

---

### Using single-element padding instead of `@()`

**Wrong:**
```powershell
New-TeaStyle -Padding 1, 2   # PowerShell parses this as two separate arguments
```

**Right:**
```powershell
New-TeaStyle -Padding @(1, 2)   # always use @() for array params
```

---

## Exercises

1. **Change the border.** Swap the `'Rounded'` border in the companion script to
   `'Double'` and `'Thick'`. Note how each looks in your terminal.

2. **Background highlight.** Add a `New-TeaText` line with `-Style (New-TeaStyle
   -Foreground 'Black' -Background 'BrightCyan')`. Notice the contrast with the
   surrounding text.

3. **Third column.** Add a third panel to the `New-TeaRow` containing a list of
   all 16 named colors as `New-TeaText` nodes, each with its own `-Foreground` style.

---

## Next Lesson

**[B-05 — Capstone: Nameable Counter](05-capstone-nameable-counter.md):** combine
everything from the Beginner track — state, interaction, conditional rendering, and
full styling — into one complete app.

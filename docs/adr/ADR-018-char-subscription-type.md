# ADR-018 - Printable-Character Subscription: `New-ElmCharSub`

| Field    | Value |
|----------|-------|
| Status   | Accepted |
| Affects  | Phase 9 (Widget Library - `New-ElmTextInput`), Phase 6 (Subscriptions) |

## Context

`New-ElmTextInput` needs to capture arbitrary printable character input. The existing subscription
system has `New-ElmKeySub`, which matches a specific `[System.ConsoleKey]` enum value. There is
no mechanism to catch "any printable char not already handled by a specific key sub."

Three designs were considered for capturing printable input.

## Options Considered

| Option | Description |
|--------|-------------|
| **Wildcard KeySub** | `New-ElmKeySub -Key '*'` matches any key. Developer checks `.Char` in handler. |
| **All-key fallthrough in Update** | No special sub; every unmatched key event passes through to Update as a raw message. Developer pattern-matches on `$msg.Char`. |
| **Dedicated `New-ElmCharSub` type** | New subscription type that fires only for printable ASCII chars (0x20-0x7E) not already consumed by a `New-ElmKeySub` in the same cycle. |

## Decision

**Dedicated `New-ElmCharSub` type.**

```powershell
New-ElmCharSub -Handler { param($e) "Input:$([string]$e.Char)" }
```

- `Invoke-ElmSubscriptions` collects all `Char`-type subs alongside key and timer subs.
- After attempting to match all `New-ElmKeySub` entries, if no match was found AND the event is a
  printable ASCII char (`[int]$e.Char -ge 0x20 -and [int]$e.Char -le 0x7E`), all char subs fire.
- Key subs always take priority; char subs never receive events already claimed by a key sub.
- Pass-through mode (raw events forwarded when no subs are active) is suppressed when char subs
  are present, the same as for key subs.

## Rationale

**Wildcard KeySub** conflates two different semantics: "I want this specific key" vs. "I want
any printable character." A wildcard would also fire for arrow keys, function keys, and modifier
combos - the developer would filter these in the handler, which is boilerplate every text input
needs to repeat.

**All-key fallthrough** removes the subscription abstraction entirely for this case. It bypasses
the subscription priority model (key subs should claim events before char subs) and forces
developers to handle raw KeyDown objects in Update, mixing input routing with business logic.

**`New-ElmCharSub`** mirrors the BubbleTea `tea.KeyMsg` distinction between named keys and rune
input. It keeps the subscription layer as the single point of input dispatch, preserves the
priority model (named key subs win), and gives developers a clean handler that receives only
printable characters without needing defensive filtering.

## Consequences

- `Invoke-ElmSubscriptions` gains a `$charSubs` collection alongside `$keySubs` and `$timerSubs`.
- The dispatch order is: key subs first → char subs for unmatched printable chars → pass-through
  only when neither key subs nor char subs are active.
- `New-ElmCharSub` is a public function; `$sub.Type -eq 'Char'` is the internal discriminator.
- Handler receives the raw `KeyDown` event object; `.Char` contains the typed character.
- Char subs do not fire for control characters, arrow keys, function keys, or modifier-only keys.

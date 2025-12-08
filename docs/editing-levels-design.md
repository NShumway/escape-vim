# Editing Levels Design (Levels 4-8)

## Overview

Levels 4-8 teach text editing using **native Vim commands**. No custom handlers - just real Vim editing.

The player edits text to match a target, then saves with `:wq`. That's it.

## Visual Layout

```
Target:  The quick brown fox jumps over the lazy dog
──────────────────────────────────────────────────────
         The quikc brown fox jumpss over teh lazy dog*
```

- **Top**: Target text (reference)
- **Divider**: Line of `─` characters
- **Bottom**: Editable text + exit tile `*`
- **Exit tile**: Green when text matches, red when it doesn't

## How It Works

1. Player uses normal Vim commands (`i`, `x`, `dw`, etc.) to edit text
2. Exit tile updates color in real-time as edits happen
3. Player moves to exit tile and types `:wq`
4. If text matches target → win. If not → lose.

## Commands

All standard Vim:
- `h/j/k/l` - movement
- `i` - insert mode
- `a` - append
- `x` - delete char
- `dw` - delete word
- `Esc` - exit insert mode
- `:wq` - save and quit (win check)

## Level YAML

```yaml
id: 4
type: editing

target_text: |
  The quick brown fox
  jumps over the lazy dog

initial_text: |
  The quikc brown fox
  jumpss over teh lazy dog

commands:
  - key: 'i'
    desc: 'insert mode'
  - key: 'x'
    desc: 'delete char'
  - key: ':wq'
    desc: 'save & exit'

blocked_categories:
  - arrows
  - search
  # etc - block what you want to restrict
```

## Implementation

### editing.vim

Minimal - just:
1. Store target text
2. Track editable region bounds
3. Compare current text to target on `:wq`
4. Update exit tile highlight (green/red)

Uses `TextChanged` autocmd to update exit status in real-time.

### No Custom Insert Handlers

Previous design had overcomplicated "space replacement" logic. Deleted.
Just use native Vim insert mode.

### No Player @ Symbol

In editing levels, there's no `@` player character drawn. The cursor IS the player.
Yellow highlight shows cursor position.

## Level Progression

| Level | Focus | New Commands |
|-------|-------|--------------|
| 4 | Basic editing | `i`, `x` |
| 5 | More practice | `i`, `x` |
| 6 | Word deletion | `dw` |
| 7 | Combined | all above |
| 8 | Under pressure | spies patrol while you edit |

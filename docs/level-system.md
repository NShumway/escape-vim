# Level System

This document describes how levels are defined, stored, built, and loaded in Escape Vim.

## Overview

The level system has three layers:

1. **Source files** - Human-authored YAML and JSON defining level content
2. **Generated files** - Vim-readable files produced by the build tool
3. **Runtime loading** - How the Vim game engine loads and runs levels

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SOURCE FILES                                    │
│                           (human-authored)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  levels/levelXX/level.yaml     Game mechanics (maze, enemies, rules)        │
│  levels/lore/levelXX.json      Narrative content (title, quotes, story)     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                         python3 tools/level_builder.py
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            GENERATED FILES                                   │
│                    (committed to git, do not edit)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  levels/levelXX/maze.txt       Text grid of the maze                        │
│  levels/levelXX/meta.vim       Vim dictionary with all level metadata       │
│  levels/levelXX/spies.vim      Spy patrol routes (if level has spies)       │
│  levels/manifest.vim           Index of all levels                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                            Vim game engine loads
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               RUNTIME                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  levels/api/level.vim          Orchestrates level loading                   │
│  levels/api/*.vim              Game engine modules                          │
│  game/ui/*.vim                 UI screens (lore, gameplay, results)         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Source Files

### level.yaml

The YAML file is the single source of truth for game mechanics. All positions use 1-indexed coordinates to match Vim conventions.

```yaml
# Level identifier (must be unique, used in manifest and save files)
id: 3

# Maze dimensions: [rows, cols]
dimensions: [50, 100]

# Player start position: [row, col] (1-indexed)
start: [3, 3]

# Exit position: [row, col] (1-indexed)
exit: [48, 98]

# Wall definitions (drawn in order)
walls:
  # Horizontal line: row, col_start, col_end
  - type: hline
    line: [6, 2, 99]

  # Vertical line: col, row_start, row_end
  - type: vline
    line: [50, 10, 40]

  # Rectangle: top, left, height, width
  - type: rect
    rect: [11, 11, 8, 15]

# Openings carved through walls (applied after walls)
openings:
  - type: hline
    line: [6, 96, 99]
  - type: point
    pos: [25, 50]

# Enemy patrol definitions
spies:
  - id: top_guard
    pattern: horizontal           # horizontal, vertical, or loop
    endpoints: [[4, 11], [4, 81]] # start and end positions
    speed: 1.0                    # movement speed multiplier

  - id: patrol1
    pattern: loop
    waypoints: [[10, 10], [10, 30], [18, 30], [18, 10]]
    direction: cw                 # cw or ccw
    speed: 0.8

# Features to enable for this level
features:
  - spies     # Enable spy collision detection (touching spy = defeat)

# Available commands (shown in sideport during gameplay)
commands:
  - {key: 'h', desc: 'move left'}
  - {key: 'j', desc: 'move down'}
  - {key: 'k', desc: 'move up'}
  - {key: 'l', desc: 'move right'}
  - {key: ':q', desc: 'escape (at exit)'}

# Command categories to block
blocked_categories:
  - arrows
  - search
  - find_char
  - word_motion
  - line_jump
  - paragraph
  - matching
  - marks
  - jump_list
  - scroll
  - insert
  - change
  - delete
  - visual
  - undo_redo

# Optional constraints
time_limit_seconds: null    # null = no limit
max_keystrokes: null        # null = no limit
```

### lore/levelXX.json

Narrative content displayed in the UI. Stored separately from game mechanics.

```json
{
  "title": "The Watchers",
  "description": "Evade patrolling spies to reach the exit.",
  "objective": "Navigate past the guards without being detected.",
  "quote": "Patience is not the ability to wait,\nbut the ability to keep a good attitude while waiting.\n\nThe Watchers never tire. You must be smarter.",
  "victory_quote": "Impressive. You slipped past the\nWatchers like a ghost.\n\nFew have made it this far.\nYou're proving to be quite capable.",
  "lore": "The corridors ahead are patrolled by the Watchers—\nrelentless guards who never tire, never sleep.\n\nYour only advantage is patience.\nStudy their patterns. Find the gaps.\nMove when they look away."
}
```

## Generated Files

### maze.txt

A text grid representing the maze. Uses `█` for walls and spaces for floors. The exit position is marked with `Q`.

```
████████████████████████████████████████
█                                      █
█  ██████████████  ██████████████████  █
█  █                              █    █
█  █  ████████████████████████    █  Q █
████████████████████████████████████████
```

### meta.vim

A Vim dictionary literal containing merged data from both `level.yaml` and `lore/levelXX.json`. This is the primary metadata file loaded by the game engine.

```vim
{
  'title': 'The Watchers',
  'description': 'Evade patrolling spies to reach the exit.',
  'objective': 'Navigate past the guards without being detected.',
  'quote': "Patience is not the ability to wait...",
  'victory_quote': "Impressive. You slipped past...",
  'lore': "The corridors ahead are patrolled...",
  'start_cursor': [3, 3],
  'exit_cursor': [48, 98],
  'maze': {'lines': 50, 'cols': 100},
  'viewport': {'lines': 50, 'cols': 100},
  'features': ['spies'],
  'commands': [
    {'key': 'h', 'desc': 'move left'},
    {'key': 'j', 'desc': 'move down'},
    {'key': 'k', 'desc': 'move up'},
    {'key': 'l', 'desc': 'move right'},
    {'key': ':q', 'desc': 'escape (at exit)'}
  ],
  'blocked_categories': ['arrows', 'search', ...],
  'time_limit_seconds': v:null,
  'max_keystrokes': v:null
}
```

### spies.vim

Generated only for levels with spy definitions. Contains patrol route data in Vim-evaluable format.

```vim
" Spy patrol data - generated by level_builder.py
[{'id': 'top_guard', 'spawn': [4, 11], 'route': [{'end': [4, 81], 'dir': 'right'}, {'end': [4, 11], 'dir': 'left'}], 'speed': 1.0}]
```

### manifest.vim

Generated by scanning all level.yaml files. Used by the game UI for level selection.

```vim
[
  {'id': 1, 'dir': 'level01', 'title': 'First Steps'},
  {'id': 2, 'dir': 'level02', 'title': 'The Maze'},
  {'id': 3, 'dir': 'level03', 'title': 'The Watchers'},
]
```

## Build Commands

```bash
# Build a single level
python3 tools/level_builder.py levels/level03

# Build all levels and regenerate manifest
python3 tools/level_builder.py --all

# Validate all levels (run after building)
python3 tools/validate_levels.py
```

## Directory Structure

```
levels/
├── api/                    # Shared game engine (not generated)
│   ├── buffer.vim
│   ├── collision.vim
│   ├── enemy.vim
│   ├── highlight.vim
│   ├── input.vim
│   ├── level.vim           # Level loading orchestration
│   ├── patrol.vim
│   ├── player.vim
│   ├── position.vim
│   └── util.vim
├── lore/                   # Narrative content (manual)
│   ├── level01.json
│   ├── level02.json
│   └── level03.json
├── level01/
│   ├── level.yaml          # Source (manual)
│   ├── maze.txt            # Generated
│   └── meta.vim            # Generated
├── level02/
│   └── ...
├── level03/
│   ├── level.yaml          # Source (manual)
│   ├── maze.txt            # Generated
│   ├── meta.vim            # Generated
│   └── spies.vim           # Generated (has spies)
├── manifest.vim            # Generated
├── viewport.vim            # Shared (not generated)
└── validate.vim            # Shared (not generated)
```

## Feature System

The `features` list in level.yaml controls which game behaviors are enabled:

| Feature | Effect |
|---------|--------|
| `spies` | Enables spy collision detection. Touching a spy triggers defeat. |

Features are processed by `Level_Load()` in `levels/api/level.vim`.

## Validation

The validation tool (`tools/validate_levels.py`) checks:

- Maze dimensions match metadata
- Start/exit positions are inside maze bounds and not on walls
- Spy spawn positions are valid
- Patrol routes don't hit walls and loop back to spawn
- All required fields are present

Run validation after any changes to source files:

```bash
python3 tools/validate_levels.py
```

## Adding a New Level

1. Create the level directory:
   ```bash
   mkdir levels/level04
   ```

2. Create `levels/level04/level.yaml` with game mechanics

3. Create `levels/lore/level04.json` with narrative content

4. Build the level:
   ```bash
   python3 tools/level_builder.py levels/level04
   ```

5. Validate:
   ```bash
   python3 tools/validate_levels.py levels/level04
   ```

6. Rebuild manifest:
   ```bash
   python3 tools/level_builder.py --all
   ```

## Testing a Level Standalone

For quick testing without the full game UI:

```bash
./tools/test_level.sh level03
```

This launches Vim directly into the level, bypassing the title screen and lore.

---

## Runtime: How Levels Are Loaded

This section describes how the Vim game engine uses the generated files at runtime.

### Game Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  TITLE       │────▶│  LORE        │────▶│  GAMEPLAY    │────▶│  RESULTS     │
│  game/ui/    │     │  game/ui/    │     │  game/ui/    │     │  game/ui/    │
│  init.vim    │     │  lore.vim    │     │  gameplay.vim│     │  results.vim │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                    │
                            ▼                    ▼
                     ┌──────────────┐     ┌──────────────┐
                     │ meta.vim     │     │ Level_Load() │
                     │ (lore field) │     │ levels/api/  │
                     └──────────────┘     │ level.vim    │
                                          └──────────────┘
```

### Level Loading Sequence

When a player starts a level, `Level_Load()` in `levels/api/level.vim` orchestrates loading:

```
Level_Load('levels/level03')
    │
    ├─▶ 1. Source API modules (in dependency order)
    │       levels/api/util.vim
    │       levels/api/position.vim
    │       levels/api/buffer.vim
    │       levels/api/highlight.vim
    │       levels/api/input.vim
    │       levels/api/player.vim
    │       levels/api/collision.vim
    │       levels/api/patrol.vim
    │       levels/api/enemy.vim
    │
    ├─▶ 2. Source viewport system
    │       levels/viewport.vim
    │
    ├─▶ 3. Load metadata
    │       eval(readfile('levels/level03/meta.vim'))
    │       → s:current_meta dictionary
    │
    ├─▶ 4. Initialize viewport
    │       ViewportInit(meta)
    │
    ├─▶ 5. Load maze buffer
    │       edit levels/level03/maze.txt
    │       Apply viewport padding
    │
    ├─▶ 6. Initialize player
    │       Player_Init(start_line, start_col)
    │       Set exit position for win detection
    │
    ├─▶ 7. Set up input blocking
    │       Input_BlockCategories(meta.blocked_categories)
    │
    ├─▶ 8. Set up collision detection
    │       CursorMoved autocommand → Collision_OnMove()
    │
    ├─▶ 9. Load spies (if spies.vim exists)
    │       eval(readfile('levels/level03/spies.vim'))
    │       Enemy_Spawn() for each spy
    │       Enemy_Start() to begin tick updates
    │
    └─▶ 10. Enable features
            Check meta.features list
            'spies' → Collision_SetSpyCallback({-> Game_LevelFailed()})
```

### Key Runtime Files

| File | Purpose | When Used |
|------|---------|-----------|
| `levels/manifest.vim` | Level index with id, dir, title | LORE screen (level selector), save system |
| `levels/levelXX/meta.vim` | All level metadata | LORE screen (quote), GAMEPLAY (objective, commands), RESULTS (victory_quote) |
| `levels/levelXX/maze.txt` | The playable maze | GAMEPLAY (loaded into buffer) |
| `levels/levelXX/spies.vim` | Spy patrol data | GAMEPLAY (parsed by Level_Load) |

### How Each meta.vim Field Is Used

| Field | Used By | Purpose |
|-------|---------|---------|
| `title` | lore.vim, sideport | Level name in UI |
| `description` | (reserved) | Brief level summary |
| `objective` | sideport | Shown during gameplay |
| `quote` | lore.vim | Commander quote before level |
| `victory_quote` | results.vim | Shown on level completion |
| `lore` | lore.vim | Story text on lore screen |
| `start_cursor` | level.vim | Player spawn position |
| `exit_cursor` | level.vim | Win condition position |
| `maze.lines/cols` | level.vim, validation | Maze dimensions |
| `viewport.lines/cols` | viewport.vim | Screen size for centering |
| `features` | level.vim | Enable game behaviors |
| `commands` | sideport | Available keys display |
| `blocked_categories` | input.vim | Keys to disable |
| `time_limit_seconds` | (future) | Optional time constraint |
| `max_keystrokes` | (future) | Optional move constraint |

### API Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `level.vim` | Orchestrates loading, holds level state |
| `position.vim` | Coordinate conversion (char ↔ byte, viewport offsets) |
| `buffer.vim` | Maze buffer manipulation |
| `highlight.vim` | Visual rendering (player, enemies, exit) |
| `input.vim` | Command blocking by category |
| `player.vim` | Player position, movement |
| `collision.vim` | Wall collision, spy collision callbacks |
| `patrol.vim` | Patrol route vector math |
| `enemy.vim` | Spy spawning, movement, tick subscription |
| `util.vim` | Shared helpers |
| `viewport.vim` | Screen centering, buffer padding |

### Manifest Usage

The manifest is read by UI code to:
1. **Level selection** (lore.vim) - Show available levels
2. **Save/load** (save.vim) - Track completed levels
3. **Progression** (state.vim) - Determine next unlocked level

```vim
" Example: Reading manifest
let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))
" → [{'id': 1, 'dir': 'level01', 'title': 'First Steps'}, ...]
```

### Spy System Runtime

When a level has spies:

1. **Load**: `spies.vim` parsed into list of spy configs
2. **Spawn**: Each spy gets `Enemy_Spawn(id, spawn_pos, route, speed)`
3. **Tick**: `Enemy_Start()` subscribes to game tick (50ms)
4. **Movement**: Each tick, spies advance along their patrol route
5. **Collision**: If `features` includes `spies`, touching one triggers defeat

```
Tick System (game/tick.vim)
    │
    ├─▶ Enemy_OnTick()
    │       For each spy:
    │         Move toward next route waypoint
    │         Update highlight position
    │
    └─▶ Collision_CheckSpies()
            Compare player pos to all spy positions
            If overlap → callback → Game_LevelFailed()
```

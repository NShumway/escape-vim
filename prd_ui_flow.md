# UI Flow & Sideport — Product Requirements Document

## 1. Overview

This document specifies the user interface flow for Escape Vim, including the sideport (command panel), screen states, transitions, and data persistence. It builds on the core game mechanics defined in `prd_escape_room_vim.md` and `prd_level_1_maze.md`.

---

## 2. Screen Dimensions

### Target Resolution
- **Primary target**: 1920×1080 fullscreen
- **Terminal grid**: ~181 columns × 65-76 rows (depends on font/terminal)
- **Layout**: 50/50 split between sideport and main area
- **Each panel**: ~90 columns wide

### Scaling
- Higher resolutions (4K, etc.): Scale up proportionally
- Lower resolutions: Not supported in v1

### Enforcement
- Game launches in fullscreen
- Built assuming 1920×1080 or larger
- If user resizes, behavior is undefined (their problem)

---

## 3. Screen States

The game has four distinct screen states:

| State | Sideport | Main Area |
|-------|----------|-----------|
| LORE | Commander portrait + quote | Lore text + level select |
| GAMEPLAY | Commander portrait + objectives + commands + timer | Maze |
| FIREWORKS | Hidden | Full-screen fireworks animation |
| RESULTS | Commander portrait + quote | Stats + leaderboard + fireworks |

### State Transitions

```
LORE ──[Enter]──> GAMEPLAY ──[:q at exit]──> FIREWORKS ──[2s timer]──> RESULTS ──[any key]──> LORE
```

---

## 4. Screen Specifications

### 4.1 LORE Screen

**See mockup**: `assets/mockups/screen1-launch.txt`

**Sideport contents:**
- Commander portrait (top, ~32 rows)
- "THE COMMANDER" title
- Commander quote (bottom, level-specific)

**Main area contents:**
- Level lore text (level-specific, ~20 lines)
- Level selector list
  - Only shows unlocked levels (completed + next)
  - Completed levels show checkmark (✓)
  - Current selection highlighted with `>`
- "Press <Enter> to begin" prompt

**Input:**
- `j`/`k`: Navigate level selector (when multiple levels unlocked)
- `<Enter>`: Start selected level

**Data sources:**
- Lore text: `levels/levelXX/lore.txt`
- Commander quote: `levels/levelXX/meta.vim` → `quote` field

### 4.2 GAMEPLAY Screen

**See mockup**: `assets/mockups/screen2-gameplay.txt`

**Sideport contents:**
- Commander portrait (top, ~32 rows)
- "THE COMMANDER" title
- Level name (e.g., "LEVEL 1: First Steps")
- Objective section
- Commands section:
  - Current level's new commands
  - All previously learned commands (cumulative)
- Timer and move counter (bottom)

**Main area contents:**
- The maze

**Input:**
- Movement keys as defined by level (hjkl for L1, +w/b for L2, etc.)
- `:q` variants at exit to complete level

**Data sources:**
- Objective: `levels/levelXX/meta.vim` → `objective` field
- Commands: `levels/levelXX/meta.vim` → `commands` field (array)
- Previous commands: Accumulated from all prior levels

### 4.3 FIREWORKS Screen

**See mockup**: `assets/mockups/screen3a-fireworks.txt`

**Full-screen animation:**
- No sideport visible
- "VICTORY!" banner (large ASCII text, centered)
- Animated fireworks bursting at random positions
- Stars twinkling on/off
- Duration: ~2 seconds
- Frame rate: ~3-4 fps (4-6 total frames)

**Variation:**
- Standard fireworks for most levels
- Special/extended fireworks for final level (configured in manifest, not per-level)

**Data sources:**
- Fireworks ASCII frames: `assets/fireworks/` directory
- Final level flag: `levels/manifest.vim` → last entry

### 4.4 RESULTS Screen

**See mockup**: `assets/mockups/screen3b-results.txt`

**Sideport contents:**
- Commander portrait (top, ~32 rows)
- "THE COMMANDER" title
- Commander victory quote (level-specific)
- "Press any key to continue" prompt

**Main area contents:**
- Animated fireworks (slower/subtler than FIREWORKS screen, continues in background)
- "MISSION ACCOMPLISHED" banner
- Level name
- Player stats:
  - Time (MM:SS)
  - Moves (keystroke count)
- Leaderboard:
  - Top 5 scores (mock data for v1)
  - Player's position highlighted

**Input:**
- Any key: Proceed to next level's LORE screen

**Data sources:**
- Victory quote: `levels/levelXX/meta.vim` → `victory_quote` field
- Leaderboard: `game/leaderboard_data.h` (compiled in, mock data)

---

## 5. Level Data Structure

### Directory Structure

```
levels/
├── manifest.vim              # Master list of all levels
├── level01/
│   ├── init.vim              # Entry point
│   ├── maze.txt              # The maze layout
│   ├── maze.vim              # Game logic (collisions, blocked commands)
│   ├── lore.txt              # Lore text for LORE screen
│   └── meta.vim              # Level metadata
├── level02/
│   └── ...
```

### manifest.vim

```vim
[
  {'id': 1, 'dir': 'level01', 'title': 'First Steps'},
  {'id': 2, 'dir': 'level02', 'title': 'Word by Word'},
  {'id': 3, 'dir': 'level03', 'title': 'Line Dancing'},
]
```

### meta.vim

```vim
{
  'title': 'First Steps',
  'objective': 'Navigate to the exit and escape.',
  'commands': [
    {'key': 'h', 'desc': 'move left'},
    {'key': 'j', 'desc': 'move down'},
    {'key': 'k', 'desc': 'move up'},
    {'key': 'l', 'desc': 'move right'},
    {'key': ':q', 'desc': 'escape (at exit)'},
  ],
  'quote': "Every expert was once a beginner.\nEvery master was once a disaster.\n\nToday, you take your first steps.",
  'victory_quote': "Well done, soldier. You've taken your\nfirst steps toward freedom.\n\nBut don't celebrate yet. The real\nchallenges lie ahead.",
  'exit_pos': [10, 26],
  'start_pos': [2, 2],
}
```

### lore.txt

Plain text file, ~20 lines max. Displayed in main area during LORE screen.

```
"Soldier. You've been trapped inside
 the VIM editor. Many have entered.
 Few have escaped.

 I've seen recruits freeze at the
 sight of that blinking cursor. Watched
 them mash Escape until their fingers
 went numb. Some are still in there,
 typing :quit over and over, hoping
 something will change.

 But you're different. I can see it.

 Your mission: learn the ancient
 commands that will set you free.
 Move with purpose. Act with precision.
 And whatever you do...

 Don't panic."

                    — The Commander
```

---

## 6. Cumulative Commands

Each level teaches new commands. The GAMEPLAY sideport shows:
1. **This level's commands** (what you're learning)
2. **Previously learned commands** (from completed levels)

### Implementation

The game tracks which levels are completed. When rendering the commands section:

```vim
" Pseudocode
let all_commands = []
for level in completed_levels
  let all_commands += level.commands
endfor
let all_commands += current_level.commands
```

Display format:
```
COMMANDS
────────
h   move left
j   move down
k   move up
l   move right
:q  escape (at exit)
────────
w   word forward      ← new this level
b   word backward     ← new this level
```

Optionally mark new commands or separate them visually.

---

## 7. Fireworks Assets

### Location

```
assets/
├── fireworks/
│   ├── frame1.txt
│   ├── frame2.txt
│   ├── frame3.txt
│   ├── frame4.txt
│   ├── frame5.txt
│   └── frame6.txt
├── fireworks_final/        # Special frames for final level
│   └── ...
└── victory_banner.txt      # "VICTORY!" ASCII art
```

### Animation Logic

- Load all frames from `assets/fireworks/`
- Cycle through frames at ~3-4 fps
- After ~2 seconds, transition to RESULTS
- For final level: use `assets/fireworks_final/` instead

This keeps fireworks art centralized, not duplicated per level.

---

## 8. Save Data

### Location

```
~/Library/Application Support/EscapeVim/
├── save.vim                # Progress and stats
```

Why `~/Library/Application Support/EscapeVim/`:
- Standard macOS location for application data
- Works when game is installed as package
- Simple to find/backup/delete

### save.vim Format

```vim
{
  'completed_levels': [1, 2, 3],
  'stats': {
    '1': {'best_time': 83, 'best_moves': 32},
    '2': {'best_time': 124, 'best_moves': 48},
    '3': {'best_time': 201, 'best_moves': 71},
  }
}
```

### Save Behavior

- **Save on**: Level completion only
- **Load on**: Game launch
- **If no save file**: Start fresh, only level 1 available
- **Mid-level quit**: No save, progress lost
- **Resume behavior**: Load to LORE screen with next incomplete level selected

---

## 9. Sideport Rendering Modes

The sideport has three distinct layouts:

### Mode 1: LORE (portrait + quote only)

```
┌────────────────────────────────────────────┐
│                                            │
│         [Commander Portrait]               │
│              (~32 rows)                    │
│                                            │
│        T H E   C O M M A N D E R           │
│                                            │
├────────────────────────────────────────────┤
│                                            │
│  [Commander Quote]                         │
│  (~8 rows)                                 │
│                                            │
└────────────────────────────────────────────┘
```

Used in: LORE screen, RESULTS screen

### Mode 2: GAMEPLAY (full info panel)

```
┌────────────────────────────────────────────┐
│                                            │
│         [Commander Portrait]               │
│              (~32 rows)                    │
│                                            │
│        T H E   C O M M A N D E R           │
│                                            │
├────────────────────────────────────────────┤
│  LEVEL N: Title                            │
│                                            │
│  OBJECTIVE                                 │
│  [objective text]                          │
│                                            │
├────────────────────────────────────────────┤
│  COMMANDS                                  │
│  [command list]                            │
│                                            │
├────────────────────────────────────────────┤
│  TIME      00:00        MOVES  0           │
└────────────────────────────────────────────┘
```

Used in: GAMEPLAY screen

### Mode 3: Hidden

Sideport not rendered. Full screen used for main content.

Used in: FIREWORKS screen

---

## 10. Implementation Notes

### Sideport as Vim Buffer

The sideport is implemented as a vertical split buffer:
- `nomodifiable` - user cannot edit
- `buftype=nofile` - not associated with a file
- `noswapfile` - no swap file
- Custom mappings to prevent closing

### Screen State Machine

```vim
let g:game_state = 'LORE'  " LORE | GAMEPLAY | FIREWORKS | RESULTS

function! GameTransition(new_state)
  let g:game_state = a:new_state
  call GameRender()
endfunction
```

### Timer for Fireworks

```vim
" After level complete
call GameTransition('FIREWORKS')
call timer_start(2000, {-> GameTransition('RESULTS')})
```

### Animation Loop for Fireworks

```vim
let s:firework_frame = 0
let s:firework_timer = -1

function! s:FireworkAnimate(timer)
  let s:firework_frame = (s:firework_frame + 1) % len(s:firework_frames)
  call s:RenderFireworkFrame(s:firework_frame)
endfunction

function! s:StartFireworks()
  let s:firework_timer = timer_start(250, function('s:FireworkAnimate'), {'repeat': -1})
endfunction

function! s:StopFireworks()
  if s:firework_timer >= 0
    call timer_stop(s:firework_timer)
  endif
endfunction
```

---

## 11. Mockup Reference

All ASCII mockups are stored in:

```
assets/mockups/
├── screen1-launch.txt      # LORE screen (initial launch)
├── screen2-gameplay.txt    # GAMEPLAY screen
├── screen3a-fireworks.txt  # FIREWORKS screen (full-screen animation)
├── screen3b-results.txt    # RESULTS screen
├── screen4-level2-lore.txt # LORE screen (after completing level 1)
└── sideport-mockup.txt     # Original sideport concept sketch
```

---

## 12. Open Questions

### Resolved
- ✓ Sideport layout variations (3 modes defined)
- ✓ Lore storage (separate lore.txt per level)
- ✓ Fireworks storage (centralized in assets/, not per-level)
- ✓ Save file location (~/Library/Application Support/EscapeVim/)
- ✓ Commander quote on launch screen (yes, in sideport)

### Remaining
- Commander expression variants (future: different portraits for different moments)
- Online leaderboard integration (separate repo, out of scope for this PRD)
- Sound effects beyond terminal bell

---

## 13. Summary

The UI flow consists of four screens (LORE → GAMEPLAY → FIREWORKS → RESULTS → LORE) with a persistent sideport showing the Commander and contextual information. Level data is stored in per-level directories with `lore.txt` and `meta.vim` files. Save data persists to `~/Library/Application Support/EscapeVim/save.vim` on level completion only. Fireworks assets are centralized to avoid duplication, with a special variant for the final level.

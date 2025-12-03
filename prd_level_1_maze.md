# Level 1: The Maze — Technical Spec

## Overview

Level 1 is a self-contained, playable maze game built on a modified Vim. The player navigates from a starting position to an exit marker using `hjkl`, then types `:q` to escape. This is the first level of "Escape Room: Vim" but should be fully playable as a standalone experience.

No side panel, no scoring, no level select — just the maze.

---

## How to Launch

```bash
./vim --clean -S levels/level01/init.vim
```

This opens vim with:
- No user config (`--clean`)
- Level initialization script that loads the maze and sets up game rules

---

## Win Condition

- Cursor is positioned on the exit marker (`Q`)
- Player enters any quit command (`:q`, `:q!`, `ZZ`, `:wq`, etc.)
- Vim exits normally (no special celebration for now)

If player tries to quit while not on the exit:
- Block the quit silently (no message — messaging comes with side panel later)

---

## Directory Structure

```
escape-vim/
├── src/                      # Vim source (with game hooks)
│   ├── ex_docmd.c            # Modified: quit command interception
│   └── ...
├── game/                     # Game logic module (C code)
│   ├── game.c                # Game state, initialization
│   ├── game.h
│   ├── block.c               # Blocked command handling
│   ├── block.h
│   └── Makefile
├── levels/
│   └── level01/
│       ├── init.vim          # Level initialization script
│       ├── maze.txt          # The maze file
│       └── maze.vim          # Vimscript: wall collision, blocked commands
├── runtime/                  # Vim runtime files
└── Makefile                  # Main build
```

### Why This Structure

- `game/` holds C code for functionality that requires vim source modification
- `levels/level01/` is self-contained — all level-specific files in one place
- `init.vim` is the entry point that sources `maze.vim` and opens `maze.txt`
- Vimscript handles wall collision; C handles quit interception

---

## The Maze

### maze.txt

```
███████████████████████████
█           █             █
█   ███     █   █████████ █
█   █           █       █ █
█   █   ███████████████ █ █
█       █               █ █
█ █████ █   █████████   █ █
█           █           █ █
█   ███████ █   █████████ █
█                         Q
███████████████████████████
```

- `█` (U+2588) — wall, cursor cannot stay here
- ` ` (space) — walkable path
- `Q` — exit (must be here to quit)
- Cursor starts at row 1, column 1 (0-indexed: the first space inside the maze)

Dimensions: 27 columns × 11 rows. Fits in any terminal.

---

## Core Mechanics

### 1. Wall Collision (Post-Move Detection)

We use Vim's `CursorMoved` autocommand, which fires *after* the cursor moves. This creates a deliberate "bounce" effect.

**Flow:**

1. Player presses movement key (`h`/`j`/`k`/`l` or any motion)
2. Vim moves cursor normally
3. `CursorMoved` fires
4. Check character under cursor
5. If on wall (`█`):
   - Enter ERROR STATE (see below)
6. If on valid cell (space or `Q`):
   - Save position as "last valid position"

**Why post-move:** Catching movement after it happens lets vim handle all the motion logic. We just validate the result and bounce back if invalid.

### 2. Error State (Wall Collision Feedback)

When player moves onto a wall:

**Visual:**
- The wall cell under cursor displays with inverted colors (black text on white background)
- This makes it obvious where the player tried to go

**Behavior:**
- All input is frozen for 500ms
- After 500ms, cursor teleports back to last valid position
- Input unfreezes, player can move again

**Audio (optional):**
- Terminal bell (`\a`) on collision

**Debouncing:**
- During the 500ms freeze, all keypresses are ignored
- This prevents mashing through walls or queueing up movements

### 3. Edit Blocking

The buffer is read-only. Implementation:
- `setlocal nomodifiable`
- Vim will show "E21: Cannot make changes, 'modifiable' is off" if they try

No custom message needed.

### 4. Quit Interception (C Hook)

Quit commands are intercepted at the C level in `ex_docmd.c` for reliable coverage.

**Commands intercepted:**
- `:q`, `:q!`, `:quit`, `:quit!`
- `:wq`, `:wq!`, `:x`, `:x!`, `:exit`, `:exit!`
- `:qa`, `:qa!`, `:qall`, `:qall!`, `:wqa`, `:wqa!`, `:xa`, `:xa!`
- `ZZ`, `ZQ` (handled via normal mode mapping calling a game function)

**Behavior:**
- Level init calls `GameSetExit(row, col)` to set exit coordinates
- Hook calls `game_check_quit_allowed()` in `game/game.c`
- Game checks if cursor is at the exit coordinates
- If yes: return true, vim exits normally
- If no: return false, quit is blocked silently

**Why C-level:** Vimscript `cabbrev` is unreliable for command interception. A C hook in `ex_docmd.c` catches all quit variants reliably.

### 5. Blocked Commands

Many vim commands would let players "cheat" by jumping over walls. These are blocked via Vimscript mappings that call a central block function.

**Blocked command categories:**

| Category | Commands | Reason |
|----------|----------|--------|
| Arrow keys | `<Up>`, `<Down>`, `<Left>`, `<Right>` | Force hjkl learning |
| Search | `/`, `?`, `n`, `N`, `*`, `#` | Teleports anywhere |
| Find char | `f`, `F`, `t`, `T`, `;`, `,` | Skips over walls on line |
| Word motion | `w`, `W`, `e`, `E`, `b`, `B` | Jumps unpredictably |
| Line jump | `gg`, `G`, `H`, `M`, `L` | Jumps to arbitrary lines |
| Paragraph | `{`, `}` | Jumps paragraphs |
| Matching | `%` | Bracket matching |
| Marks | `'`, `` ` ``, `m` | Arbitrary jumps |
| Jump list | `<C-O>`, `<C-I>` | History navigation |
| Scrolling | `<C-D>`, `<C-U>`, `<C-F>`, `<C-B>` | Page scrolling |

**Allowed commands:**
- `h`, `j`, `k`, `l` — the whole point
- `0`, `$`, `^` — line navigation (wall bounce handles invalid destinations)
- `:` — command mode (for `:q`)

**Block function design:**

```vim
" Central block function - designed for future "nice try" messaging
" @param cmd_name: string identifying the blocked command (e.g., "search", "arrow")
function! g:GameBlockCommand(cmd_name)
  " For now: silent no-op
  " Future: call side panel to show "Nice try! Use hjkl to move."
  return ''
endfunction
```

**Mapping pattern:**

```vim
" Arrow keys
nnoremap <Up>    :call g:GameBlockCommand('arrow')<CR>
nnoremap <Down>  :call g:GameBlockCommand('arrow')<CR>
nnoremap <Left>  :call g:GameBlockCommand('arrow')<CR>
nnoremap <Right> :call g:GameBlockCommand('arrow')<CR>

" Search
nnoremap /       :call g:GameBlockCommand('search')<CR>
nnoremap ?       :call g:GameBlockCommand('search')<CR>
nnoremap n       :call g:GameBlockCommand('search')<CR>
nnoremap N       :call g:GameBlockCommand('search')<CR>

" Word motions
nnoremap w       :call g:GameBlockCommand('word')<CR>
nnoremap W       :call g:GameBlockCommand('word')<CR>
nnoremap e       :call g:GameBlockCommand('word')<CR>
nnoremap E       :call g:GameBlockCommand('word')<CR>
nnoremap b       :call g:GameBlockCommand('word')<CR>
nnoremap B       :call g:GameBlockCommand('word')<CR>

" ... etc for all blocked commands
```

---

## Implementation Approach

**Hybrid: Vimscript + C hooks**

| Feature | Implementation |
|---------|----------------|
| Wall collision detection | Vimscript (`CursorMoved` autocommand) |
| Error state / bounce | Vimscript (`timer_start()`, `matchadd()`) |
| Blocked commands | Vimscript (mappings calling `g:GameBlockCommand()`) |
| Quit interception | C hook in `ex_docmd.c` |
| Edit blocking | Vimscript (`nomodifiable`) |

This gives us fast iteration on game logic while ensuring quit commands are reliably intercepted.

---

## Technical Details

### Tracking Last Valid Position

```vim
let s:last_valid_pos = [1, 1]  " [line, col], 1-indexed

function! s:OnCursorMoved()
  if s:in_error_state
    return
  endif

  let char = getline('.')[col('.') - 1]
  if char == '█'
    call s:EnterErrorState()
  else
    let s:last_valid_pos = [line('.'), col('.')]
  endif
endfunction
```

### Error State Implementation

```vim
let s:in_error_state = 0
let s:error_match_id = 0

function! s:EnterErrorState()
  let s:in_error_state = 1

  " Visual: highlight current cell inverted
  let s:error_match_id = matchadd('ErrorCell', '\%' . line('.') . 'l\%' . col('.') . 'c.')

  " Optional: beep
  " call feedkeys("\<C-G>", 'n')

  " Freeze for 500ms, then restore
  call timer_start(500, {-> s:ExitErrorState()})
endfunction

function! s:ExitErrorState()
  let s:in_error_state = 0

  " Remove highlight
  if s:error_match_id
    call matchdelete(s:error_match_id)
    let s:error_match_id = 0
  endif

  " Teleport back
  call cursor(s:last_valid_pos[0], s:last_valid_pos[1])
endfunction
```

### Highlight Group

```vim
highlight ErrorCell cterm=reverse gui=reverse
```

### Input Freeze During Error State

Map all keys to no-op during error state:

```vim
function! s:MaybeBlockInput()
  return s:in_error_state ? '' : v:char
endfunction
```

Or simpler: the 500ms is short enough that queued keys will be processed after the cursor is restored to a valid position, and the next `CursorMoved` will handle it.

Actually, we need to block input during the freeze. Options:
1. Remap all normal mode keys during error state
2. Use `getchar()` in a loop to consume keypresses during freeze
3. Set a flag and check it in mappings

Simplest: During error state, set `s:in_error_state = 1`. In `CursorMoved`, if this flag is set, immediately restore position and return. This means rapid keypresses will just keep bouncing back.

### Quit Interception (C Implementation)

The exit location is set by coordinates (from level config), not by character detection. This prevents issues if a user types `Q` elsewhere during editing levels.

**File: `game/game.h`**

```c
#ifndef GAME_H
#define GAME_H

// Set the exit position (called from Vimscript during level init)
// row and col are 1-indexed (vim convention)
void game_set_exit(int row, int col);

// Returns 1 if quit is allowed (cursor at exit position), 0 otherwise
int game_check_quit_allowed(void);

#endif
```

**File: `game/game.c`**

```c
#include "game.h"
#include "vim.h"  // For cursor position

static int exit_row = -1;  // 1-indexed
static int exit_col = -1;  // 1-indexed

void game_set_exit(int row, int col) {
    exit_row = row;
    exit_col = col;
}

int game_check_quit_allowed(void) {
    if (exit_row < 0 || exit_col < 0) {
        return 1;  // No exit set, allow quit (shouldn't happen)
    }

    int cur_row = curwin->w_cursor.lnum;       // 1-indexed
    int cur_col = curwin->w_cursor.col + 1;    // Convert 0-indexed to 1-indexed

    return (cur_row == exit_row && cur_col == exit_col);
}
```

**Exposing to Vimscript**

Register `game_set_exit` as a vim function so level init can call it:

```c
// In game initialization (or vim's function registration)
// Registers GameSetExit(row, col) as a callable Vimscript function
```

**Level init calls:**

```vim
" In init.vim
call GameSetExit(10, 26)  " Row 10, column 26 (where Q is in the maze)
```

**Hook in `src/ex_docmd.c`**

Find where quit commands are processed and add:

```c
#include "game/game.h"

// In the quit command handler (ex_quit, do_quit, etc.)
if (!game_check_quit_allowed()) {
    // Block quit silently
    return;
}
```

**ZZ and ZQ handling (Vimscript)**

These normal mode commands bypass ex commands, so we check position in Vimscript:

```vim
nnoremap ZZ :call <SID>GameTryQuit()<CR>
nnoremap ZQ :call <SID>GameTryQuit()<CR>

function! s:GameTryQuit()
  " Check if at exit position (must match what was passed to GameSetExit)
  if line('.') == 10 && col('.') == 26
    quit!
  endif
  " Silent block
endfunction
```

Note: The hardcoded `10, 26` should come from a shared config. For Level 1 we can hardcode; future levels should read from `meta.vim`.

---

## init.vim (Entry Point)

```vim
" Level 1: The Maze
" Launch with: vim --clean -S levels/level01/init.vim

" Load the maze
edit levels/level01/maze.txt

" Load game logic
source levels/level01/maze.vim

" Position cursor at start
call cursor(2, 2)

" Make buffer read-only
setlocal nomodifiable
setlocal buftype=nofile
setlocal noswapfile

" Clean UI
set laststatus=0
set noshowcmd
set noshowmode
set shortmess+=F
```

---

## Player Experience

1. Player runs `./vim --clean -S levels/level01/init.vim`
2. Maze appears, cursor is inside the maze at start position
3. Player navigates with `hjkl` (or other motions)
4. Moving into a wall: cursor appears on wall (inverted), freezes 500ms, bounces back
5. Player reaches `Q` and types `:q`
6. Vim exits — level complete

---

## Files to Create

### Level Files
| File | Purpose |
|------|---------|
| `levels/level01/maze.txt` | The maze layout |
| `levels/level01/maze.vim` | Vimscript game logic (wall collision, blocked commands) |
| `levels/level01/init.vim` | Entry point script |

### Game Module (C)
| File | Purpose |
|------|---------|
| `game/game.h` | Game state API |
| `game/game.c` | Game state, quit checking |
| `game/Makefile` | Build game module |

### Vim Modifications
| File | Change |
|------|--------|
| `src/ex_docmd.c` | Add hook to call `game_check_quit_allowed()` before quit |
| `src/Makefile` | Link `game/` module into vim build |

---

## Implementation Order

Build in this order to get a playable game incrementally:

### Phase 1: Basic Playable Maze (Vimscript only)
1. Create `levels/level01/maze.txt`
2. Create `levels/level01/init.vim` (basic setup, cursor positioning)
3. Create `levels/level01/maze.vim` with:
   - `CursorMoved` autocommand for wall detection
   - Error state with inverted highlight and 500ms bounce
   - `nomodifiable` for edit blocking
   - Blocked command mappings (arrow keys, search, etc.)
   - `ZZ`/`ZQ` mappings for quit check

**Milestone:** Can navigate maze, walls bounce back, `:q` works everywhere (no restriction yet)

### Phase 2: Quit Interception (C hook)
4. Create `game/game.h` and `game/game.c`
5. Modify `src/ex_docmd.c` to call `game_check_quit_allowed()`
6. Update build to link game module

**Milestone:** Full Level 1 playable — can only quit when on `Q`

### Phase 3: Polish
8. Test all blocked commands
9. Test edge cases (rapid input, etc.)
10. Tune timing if needed

---

## Testing Checklist

### Movement
- [ ] `hjkl` movement works on open spaces
- [ ] `0`, `$`, `^` work (bounce if landing on wall)
- [ ] Moving into wall triggers error state (inverted display)
- [ ] Cursor returns to previous position after 500ms
- [ ] Rapid keypresses during error state don't break anything

### Blocked Commands
- [ ] Arrow keys (`<Up>`, `<Down>`, `<Left>`, `<Right>`) do nothing
- [ ] Search commands (`/`, `?`, `n`, `N`, `*`, `#`) do nothing
- [ ] Word motions (`w`, `e`, `b`, `W`, `E`, `B`) do nothing
- [ ] Line jumps (`gg`, `G`, `H`, `M`, `L`) do nothing
- [ ] Find char (`f`, `F`, `t`, `T`, `;`, `,`) do nothing
- [ ] Paragraph jumps (`{`, `}`) do nothing
- [ ] Bracket matching (`%`) does nothing
- [ ] Marks (`'`, `` ` ``, `m`) do nothing
- [ ] Jump list (`<C-O>`, `<C-I>`) do nothing
- [ ] Scrolling (`<C-D>`, `<C-U>`, `<C-F>`, `<C-B>`) do nothing

### Editing
- [ ] Buffer is not editable (`i`, `x`, `dd` etc. show vim's read-only error)

### Quit Interception
- [ ] `:q` while on `Q` exits vim
- [ ] `:q` while NOT on `Q` does nothing
- [ ] `:q!`, `:wq`, `:wq!`, `:x` behave same as `:q`
- [ ] `:qa`, `:qa!`, `:qall` behave same as `:q`
- [ ] `ZZ` while on `Q` exits vim
- [ ] `ZZ` while NOT on `Q` does nothing
- [ ] `ZQ` behaves same as `ZZ`

### Visual
- [ ] Works in basic terminal (no color required, just inverse video)
- [ ] Maze fits in 80x24 terminal

---

## Not in Scope (Future Levels)

- Side panel UI
- Scoring (keystrokes, time)
- Level select
- `--level=N` command line flag
- Celebration on win
- Sound effects beyond terminal bell

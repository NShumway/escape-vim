# Escape Room: Vim — Product Requirements Document (PRD)

## 1. Overview
Escape Room: Vim is a fork of the official Vim editor, modified to function as a short, game-like, educational experience. Players progress through Vimtutor-inspired levels, each requiring use of specific Vim concepts to transform a provided file into a correct target file. A built-in side panel offers guidance, scores, and navigation.

The project demonstrates direct control over Vim's codebase by modifying input handling, UI behavior, and quitting logic while retaining Vim's license and open-source nature.

---

## 2. Goals
- Teach beginners core Vim concepts through interactive puzzles.
- Develop a fun, short, replayable game based on real Vim behavior.
- Demonstrate mastery over the Vim repository via targeted modifications.
- Keep gameplay self-contained and robust on macOS terminals.

Non-goal: Preventing advanced users from bypassing restrictions via obscure Vim motions. The goal is education, not anti-hacker security.

---

## 3. High-Level Features

### 3.1 Level-Based Gameplay
- Each level corresponds roughly to one section of *vimtutor*.
- Level structure:
  - `lesson.txt`: The file the user edits.
  - `expected.txt`: Exact file state required to finish.
  - `meta.json`: Level configuration metadata.
- Player must edit `lesson.txt` until it matches `expected.txt`.
- On completion: scorer shows time + keystrokes, then moves to next level.

### 3.2 Side Panel UI (Inside Vim)
- Implemented as a vertical split.
- Displays:
  - Level title
  - Objective
  - Tips
  - Keystroke counter
  - Timer
  - Hints / actions (retry, next level)
- Marked as unmodifiable and cannot be closed by the user.
- Quit commands are redirected back into the game logic.

### 3.3 Score Tracking
- Track:
  - Keystrokes
  - Completion time
- Recorded at level completion.

### 3.4 Leaderboards (Basic Anti-Cheat)
Two mechanisms:
1. **Offline Static Leaderboard**
   - Prepopulated with humorous / fictional names.
   - Always available, no networking needed.

2. **Optional Online Leaderboard** (Cloudflare Worker)
   - Simple API endpoint for posting scores.
   - Basic validation (min/max reasonable bounds).
   - Optional HMAC signature using a built-in shared secret.

Leaderboard UI merges offline + online scores.

---

## 4. Technical Requirements

### 4.1 Vim Modifications
All gameplay behavior requires modifying the Vim codebase.

Core changes:
- **Arrow key blocking:**
  - Intercept the four canonical Vim keycodes: `K_UP`, `K_DOWN`, `K_LEFT`, `K_RIGHT`.
  - Reject movement or show a gentle error.
- **Quit interception:**
  - Override `:q`, `:q!`, `ZZ`, `ZQ`, `:wq`.
  - If level unsolved → display error.
  - If solved → proceed to completion screen.
- **Disable unsafe commands:**
  - `:!`, `:shell`, `:source`, etc.
- **Prevent closing the side panel:**
  - Detect attempts to close its buffer and re-route.
- **Startup argument:** `--level=N`.
  - Initializes game mode.
  - Loads level structure.
  - Configures side panel.
- **Keystroke logging:**
  - Increment a global counter for each accepted key.
  - Timestamp at level start/end.
- **Diff checking:**
  - After each quit attempt or on demand, compare buffer to `expected.txt`.

### 4.2 Level Definition Structure
```
levels/
  manifest.vim              # master list of all levels
  level01/
    lesson.txt
    expected.txt
    meta.vim
  level02/
    lesson.txt
    expected.txt
    meta.vim
  ...
```

### Manifest File (`levels/manifest.vim`)
Vimscript dictionary syntax, parsed natively by vim:
```vim
[
  {'id': 1, 'dir': 'level01', 'title': 'Basic Movement'},
  {'id': 2, 'dir': 'level02', 'title': 'Deleting Text'},
  {'id': 3, 'dir': 'level03', 'title': 'Insert Mode'},
]
```

### Example `meta.vim`
Vimscript dictionary syntax (no external JSON parser needed):
```vim
{
  'title': 'Basic Movement',
  'description': 'Learn hjkl and basic mode switching.',
  'start_cursor': [0, 0],
  'start_commands': ['set number'],
  'forbidden_commands': ['q!', 'wq!', '!', 'shell', 'source'],
  'time_limit_seconds': v:null,
  'max_keystrokes': v:null
}
```

---

## 5. User Flow
1. Launch game with:
   ```
   vim --level=1
   ```
2. Vim loads level files and opens side panel.
3. User edits the file.
4. Attempting to quit triggers win check.
5. If solved → celebrate, record score, show scoreboard.
6. Player chooses next level or exit game.

---

## 6. Platform & Environment
- macOS terminal only for v1.
- No GUI support in v1.
- Must run without needing plugins or user configurations.
- Force `--clean` or equivalent to ignore user `.vimrc`.

---

## 7. Architecture Decisions

### 7.1 Repository Structure
Vim source is placed at the root level, not nested. This project is a divergent fork, not a tracking fork — we do not plan to merge upstream changes. The directory structure reflects that this is "escape-vim," a standalone product built on a vim snapshot.

```
escape-vim/
├── src/                      # vim's source (with hook modifications)
│   ├── normal.c              # vim file (add hooks here)
│   ├── ex_docmd.c            # vim file (add hooks here)
│   ├── getchar.c             # vim file (add hooks here)
│   ├── main.c                # vim file (add --level flag here)
│   ├── testdir/              # vim's test directory
│   │   ├── test_game_*.vim   # our game tests go here
│   │   └── ...
│   └── ...
│
├── game/                     # NEW: game logic (our code, separate from vim)
│   ├── game.c                # main game state, init, teardown
│   ├── game.h
│   ├── level.c               # level loading, validation, diffing
│   ├── level.h
│   ├── score.c               # keystroke counting, timer
│   ├── score.h
│   ├── panel.c               # side panel UI rendering
│   ├── panel.h
│   ├── input_filter.c        # arrow blocking, command interception
│   ├── input_filter.h
│   ├── leaderboard.c         # offline + online leaderboard client
│   ├── leaderboard.h
│   ├── leaderboard_data.h    # fake names, seed scores (compiled in)
│   ├── automation.c          # nested vim spawning, scripted sequences
│   ├── automation.h
│   └── config.h              # endpoint URLs, compile-time constants
│
├── levels/                   # level definitions (data, not code)
│   ├── level01/
│   │   ├── lesson.txt
│   │   ├── expected.txt
│   │   └── meta.json
│   └── ...
│
├── scripts/                  # build and distribution
│   ├── build.sh              # configure + make wrapper
│   └── package.sh            # create macOS .app bundle or .dmg
│
├── runtime/                  # vim's runtime (help, syntax, etc.)
├── Makefile                  # vim's makefile (extended to build game/)
└── README.md
```

### 7.2 Code Organization Principles

**Hooks in vim files, logic in `game/`.**

Modifications to vim source files (`normal.c`, `ex_docmd.c`, etc.) should be minimal one-liner hooks that call into the `game/` module. This keeps vim modifications small and makes it obvious what's upstream vim vs. our code.

Example pattern in `normal.c`:
```c
#include "game/input_filter.h"

if (game_should_block_key(c)) {
    game_show_arrow_warning();
    return;
}
```

### 7.3 Testing Strategy

Follow vim's existing test patterns:
- Tests live in `src/testdir/`, not colocated with source
- Tests are written in Vimscript using vim's `assert_equal()`, `assert_true()`, etc.
- Tests run by launching vim: `make test_game_level`
- Naming convention: `test_game_<feature>.vim`

This approach tests actual vim behavior rather than C internals, which is appropriate since most game logic manifests as editor behavior.

### 7.4 Upstream Relationship

**No upstream merges planned.**

Vim's creator Bram Moolenaar passed away in August 2023. Since then, vim is in maintenance mode with incremental improvements (autocomplete polish, diff UI) but no architectural changes. The areas we're modifying (input handling, command execution, quit logic) are stable.

Security fixes are the only thing worth monitoring, but for a local game, the risk is low.

### 7.5 Build and Distribution

macOS only for v1. The `scripts/` directory handles:
- `build.sh` — wraps `./configure && make` with any needed flags
- `package.sh` — creates distributable `.app` bundle or `.dmg`

### 7.6 Online Leaderboard

The online leaderboard (Cloudflare Worker) is developed in a **separate repository**. This repo only contains the client code (`game/leaderboard.c`) that connects to it. The endpoint URL is configured in `game/config.h`.

---

## 8. Open Questions
These items need research or design decisions as implementation progresses:

### 8.1 Side Panel Implementation
- Should the side panel be a Vim buffer or a custom drawn overlay?
  - Buffer split is simpler.
  - Custom UI avoids user interaction issues.

### 8.2 Handling Window Closing
- Should we remap `:q` when issued inside the side panel buffer?
- Should side panel be marked with a custom flag to reject its closure?

### 8.3 Diff Algorithm
- Use Vim's internal diff logic or load expected file and perform a custom comparison?
- Performance tradeoffs for large lesson files?

### 8.4 Level Completion Criteria
- Exact match only, or allow whitespace tolerance?
- Should navigation-only levels require only cursor location?

### 8.5 Scoring Model
- How do we define minimum possible keystrokes for sanity checking?
- Should replay logs be optionally saved for validation?

### 8.6 Online Leaderboard Details
- Do we want usernames/passwords, or anonymous session tokens?
- How do we handle version mismatches between client and server?

### 8.7 Extensibility
- Should we eventually allow user-created community levels?
- Should level metadata support more advanced rules later?

---

## 9. Milestones
1. **Milestone 1:** Fork Vim, add `--level` flag, load lesson and side panel.
2. **Milestone 2:** Implement arrow key blocking and quit interception.
3. **Milestone 3:** Implement diff-based win checking.
4. **Milestone 4:** Add scoring + results screen.
5. **Milestone 5:** Implement offline leaderboard.
6. **Milestone 6:** Implement online leaderboard.
7. **Milestone 7:** Polish UI, add all levels, prepare release.

---

## 10. Licensing
- Follow Vim's charityware license as-is.
- Add disclaimer on startup.
- Keep fork fully public on GitHub.

---

## 11. Summary
Escape Room: Vim gamifies Vim's learning path using real Vim mechanics. Core technical work involves forking Vim, intercepting input and quit commands, embedding a side panel UI, and defining a structured format for levels. The result is a short, fun, educational experience that demonstrates mastery over the Vim source while helping new users learn it intuitively.

# Debug Logging

This document describes the debug logging system for Escape Vim development.

## Overview

The game includes a debug logging system that writes timestamped messages to a log file. This is useful for diagnosing issues that flash by too quickly to read, or for tracing execution flow.

## When Logging is Enabled

| Launch Method | Debug Logging |
|---------------|---------------|
| `./play.sh` | **ON** (development) |
| Built app bundle | **OFF** (production) |

The `play.sh` script explicitly enables debug mode:
```bash
./src/vim --clean -c "let g:escape_vim_debug=1" -S game/ui/init.vim
```

Production builds don't set this variable, so `g:escape_vim_debug` defaults to `0` (off).

## Log File Location

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/EscapeVim/debug.log` |
| Linux | `~/.local/share/escapevim/debug.log` |

The log file is **truncated on each launch** - only the most recent session is kept.

## Viewing Logs

After running the game and reproducing an issue:

```bash
# macOS
cat ~/Library/Application\ Support/EscapeVim/debug.log

# Or with tail for live monitoring (in another terminal)
tail -f ~/Library/Application\ Support/EscapeVim/debug.log
```

## Log Format

Each log line includes a timestamp:
```
[HH:MM:SS] message
```

Example output:
```
=== Escape Vim Debug Log ===
Started: 2024-01-15 14:32:01

[14:32:01] Debug mode initialized
[14:32:01] Game_Start: Initializing game
[14:32:01] Game_Start: Loading manifest
[14:32:01] Game_Start: Found 3 levels in manifest
[14:32:01] Game_Start: Completed levels: [1, 2]
[14:32:01] GameTransition: LORE -> LORE
[14:32:01] GameTransition: Entered LORE
[14:32:05] GameTransition: LORE -> GAMEPLAY
[14:32:05] Level_Load: Starting load of levels/level03
[14:32:05] Level_Load: APIs loaded
[14:32:05] Level_Load: Reading meta from levels/level03/meta.vim
[14:32:05] Level_Load: Meta parsed, title=The Watchers
[14:32:05] GameTransition: Entered GAMEPLAY
```

## Adding Debug Logging

### Available Functions

```vim
" Basic log message
call Debug_Log('Something happened')

" Log with context (module/function name)
call Debug_LogContext('MyModule', 'Processing item ' . l:item_id)

" Log an error (prefixed with ERROR:)
call Debug_Error('Failed to load file: ' . l:path)
```

### Conventions

1. **Prefix with context** - Include the function or module name:
   ```vim
   call Debug_Log('Level_Load: Starting load of ' . a:level_path)
   ```

2. **Log at key points**:
   - Function entry (with parameters)
   - Important state changes
   - Before/after risky operations (file reads, eval)
   - Error conditions

3. **Keep messages concise** - The log can get long; make each line meaningful:
   ```vim
   " Good
   call Debug_Log('GameTransition: LORE -> GAMEPLAY')

   " Too verbose
   call Debug_Log('The GameTransition function is now transitioning from the LORE state to the GAMEPLAY state')
   ```

4. **Include relevant data** - Log values that help diagnose issues:
   ```vim
   call Debug_Log('Game_Start: Found ' . len(s:manifest_cache) . ' levels')
   call Debug_Log('Game_Start: Completed levels: ' . string(s:completed_levels_cache))
   ```

5. **Wrap risky evals** - For parsing files that might fail:
   ```vim
   try
     let l:data = eval(l:content)
     call Debug_Log('Parsed successfully')
   catch
     call Debug_Error('Parse failed: ' . v:exception)
     throw v:exception
   endtry
   ```

### Performance Note

All `Debug_*` functions check `g:escape_vim_debug` first and return immediately if logging is disabled. There's minimal overhead in production, but avoid logging inside tight loops (like cursor movement handlers).

## Implementation

The debug system is implemented in `game/debug.vim` and loaded first in `game/ui/init.vim`:

```vim
source game/debug.vim
call Debug_Init()
```

`Debug_Init()` creates the log directory if needed and truncates the log file.

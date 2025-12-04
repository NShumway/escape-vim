" Save/Load System for Escape Vim
" Persists game progress to ~/.escape-vim/save.vim

" ============================================================================
" Configuration
" ============================================================================

let s:save_dir = expand('~/.escape-vim')
let s:save_file = s:save_dir . '/save.vim'

" ============================================================================
" Save Data Structure
" ============================================================================

" Default empty save data
let s:default_save = {'completed_levels': [], 'stats': {}}

" ============================================================================
" File Operations
" ============================================================================

" Load save data from disk
" @return: save data dictionary
function! Save_Load()
  if !filereadable(s:save_file)
    return copy(s:default_save)
  endif

  try
    let l:content = join(readfile(s:save_file), '')
    let l:data = eval(l:content)
    return l:data
  catch
    " Corrupted save file - return default
    return copy(s:default_save)
  endtry
endfunction

" Write save data to disk
" @param data: save data dictionary
function! Save_Write(data)
  " Ensure directory exists
  if !isdirectory(s:save_dir)
    call mkdir(s:save_dir, 'p')
  endif

  " Format the save data
  let l:lines = [string(a:data)]
  call writefile(l:lines, s:save_file)
endfunction

" ============================================================================
" Progress Operations
" ============================================================================

" Mark a level as completed and save stats
" @param level_id: numeric level ID
" @param time_seconds: completion time in seconds
" @param moves: number of moves/keystrokes
function! Save_CompleteLevel(level_id, time_seconds, moves)
  let l:save = Save_Load()

  " Add to completed levels if not already there
  if index(l:save.completed_levels, a:level_id) < 0
    call add(l:save.completed_levels, a:level_id)
  endif

  " Update stats (keep best)
  let l:level_key = string(a:level_id)
  if !has_key(l:save.stats, l:level_key)
    let l:save.stats[l:level_key] = {'best_time': a:time_seconds, 'best_moves': a:moves}
  else
    let l:existing = l:save.stats[l:level_key]
    if a:time_seconds < l:existing.best_time
      let l:existing.best_time = a:time_seconds
    endif
    if a:moves < l:existing.best_moves
      let l:existing.best_moves = a:moves
    endif
  endif

  call Save_Write(l:save)
endfunction

" Check if a level is completed
" @param level_id: numeric level ID
" @return: 1 if completed, 0 otherwise
function! Save_IsLevelCompleted(level_id)
  let l:save = Save_Load()
  return index(l:save.completed_levels, a:level_id) >= 0
endfunction

" Get stats for a level
" @param level_id: numeric level ID
" @return: stats dictionary or empty dict if not played
function! Save_GetLevelStats(level_id)
  let l:save = Save_Load()
  let l:level_key = string(a:level_id)
  return get(l:save.stats, l:level_key, {})
endfunction

" Get list of unlocked levels (completed + next)
" @return: list of level IDs
function! Save_GetUnlockedLevels()
  let l:save = Save_Load()
  let l:completed = get(l:save, 'completed_levels', [])
  let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))

  let l:unlocked = copy(l:completed)

  " Add next uncompleted level
  for l:entry in l:manifest
    if index(l:completed, l:entry.id) < 0
      call add(l:unlocked, l:entry.id)
      break
    endif
  endfor

  " If list is empty, at least level 1 is unlocked
  if empty(l:unlocked)
    let l:unlocked = [1]
  endif

  return l:unlocked
endfunction

" Reset all save data (for testing/debug)
function! Save_Reset()
  call Save_Write(copy(s:default_save))
endfunction

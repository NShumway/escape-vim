" Game State Machine for Escape Vim
" Handles LORE/GAMEPLAY/FIREWORKS/RESULTS screen states

" ============================================================================
" State Management
" ============================================================================

" Current game state: 'LORE' | 'GAMEPLAY' | 'FIREWORKS' | 'RESULTS' | 'DEFEAT'
let g:game_state = 'LORE'

" Current level data
let g:current_level_id = 1
let g:current_level_meta = {}
let g:current_level_path = ''

" Game statistics for current run
let g:game_start_time = 0
let g:game_move_count = 0
let g:game_final_time = 0
let g:game_final_moves = 0

" Timer IDs for cleanup
let s:firework_timer = -1
let s:transition_timer = -1

" ============================================================================
" State Transitions
" ============================================================================

" Transition to a new game state
" @param new_state: 'LORE' | 'GAMEPLAY' | 'FIREWORKS' | 'RESULTS'
function! GameTransition(new_state)
  let l:old_state = g:game_state
  let g:game_state = a:new_state

  " Clean up old state
  call s:CleanupState(l:old_state)

  " Enter new state
  call s:EnterState(a:new_state)
endfunction

" Internal: Cleanup when leaving a state
function! s:CleanupState(state)
  if a:state == 'GAMEPLAY'
    " Clear exit position so :q works normally on between-level screens
    call gamesetexit(0, 0)
  elseif a:state == 'FIREWORKS'
    call Fireworks_Stop()
  elseif a:state == 'DEFEAT'
    call Defeat_Stop()
  endif
endfunction

" Internal: Initialize when entering a state
function! s:EnterState(state)
  if a:state == 'LORE'
    call Lore_Render()
  elseif a:state == 'GAMEPLAY'
    call Gameplay_Start()
  elseif a:state == 'FIREWORKS'
    call Fireworks_Start()
    " Auto-transition to RESULTS after 2 seconds
    let s:transition_timer = timer_start(2000, {-> GameTransition('RESULTS')})
  elseif a:state == 'RESULTS'
    call Results_Render()
  elseif a:state == 'DEFEAT'
    call Defeat_Start()
    " Auto-transition back to LORE after 2 seconds (retry level)
    let s:transition_timer = timer_start(2000, {-> GameTransition('LORE')})
  endif
endfunction

" ============================================================================
" Level Management
" ============================================================================

" Quit the game with an error message visible to the user
" @param message: Error message to display after quitting
function! Game_QuitWithError(message)
  " Clear the screen and show error
  enew!
  setlocal modifiable
  setlocal buftype=nofile
  call setline(1, '')
  call setline(2, '  ERROR: ' . a:message)
  call setline(3, '')
  call setline(4, '  Press any key to exit...')
  setlocal nomodifiable
  redraw

  " Wait for keypress then quit
  call getchar()
  qa!
endfunction

" Load level metadata without starting gameplay
" @param level_id: numeric level ID
" @return: 1 on success, 0 on failure (will quit with error)
function! Game_LoadLevelMeta(level_id)
  let g:current_level_id = a:level_id

  " Read manifest to find level directory
  let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))

  let l:found = 0
  for l:entry in l:manifest
    if l:entry.id == a:level_id
      let g:current_level_path = 'levels/' . l:entry.dir
      let l:found = 1
      break
    endif
  endfor

  if !l:found
    call Game_QuitWithError("Level '" . a:level_id . "' not found in manifest")
    return 0
  endif

  " Load the metadata
  let l:meta_path = g:current_level_path . '/meta.vim'

  if !filereadable(l:meta_path)
    call Game_QuitWithError("Level metadata not found: " . l:meta_path)
    return 0
  endif

  let g:current_level_meta = eval(join(readfile(l:meta_path), ''))
  return 1
endfunction

" Get cumulative commands from all completed levels + current
" @return: list of command dictionaries
function! Game_GetAllCommands()
  let l:all_commands = []
  let l:save = Save_Load()
  let l:completed = get(l:save, 'completed_levels', [])

  " Read manifest
  let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))

  " Add commands from completed levels
  for l:entry in l:manifest
    if index(l:completed, l:entry.id) >= 0
      let l:meta_path = 'levels/' . l:entry.dir . '/meta.vim'
      if filereadable(l:meta_path)
        let l:meta = eval(join(readfile(l:meta_path), ''))
        let l:all_commands += get(l:meta, 'commands', [])
      endif
    endif
  endfor

  " Add current level's commands (if not already included)
  if index(l:completed, g:current_level_id) < 0
    let l:all_commands += get(g:current_level_meta, 'commands', [])
  endif

  return l:all_commands
endfunction

" ============================================================================
" Game Lifecycle
" ============================================================================

" Start the game from the beginning (called on launch)
function! Game_Start()
  " Load save data
  let l:save = Save_Load()

  " Determine which level to show
  let l:completed = get(l:save, 'completed_levels', [])
  if empty(l:completed)
    let g:current_level_id = 1
  else
    " Find next incomplete level
    let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))
    let g:current_level_id = 1
    for l:entry in l:manifest
      if index(l:completed, l:entry.id) < 0
        let g:current_level_id = l:entry.id
        break
      endif
    endfor
  endif

  " Load level metadata
  call Game_LoadLevelMeta(g:current_level_id)

  " Start in LORE state
  call GameTransition('LORE')
endfunction

" Called when player completes a level (win conditions met)
function! Game_LevelComplete()
  " Calculate and store final stats (so they don't keep ticking)
  let g:game_final_time = localtime() - g:game_start_time
  let g:game_final_moves = g:game_move_count

  " Save progress
  call Save_CompleteLevel(g:current_level_id, g:game_final_time, g:game_final_moves)

  " Transition to fireworks
  call GameTransition('FIREWORKS')
endfunction

" Called when player quits without meeting win conditions
function! Game_LevelFailed()
  " NO save, NO unlock, NO leaderboard
  " Just transition to defeat screen (will auto-return to LORE)
  call GameTransition('DEFEAT')
endfunction

" Called to advance to next level after results
function! Game_NextLevel()
  let l:save = Save_Load()
  let l:completed = get(l:save, 'completed_levels', [])
  let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))

  " Find next level
  let l:next_id = -1
  for l:entry in l:manifest
    if index(l:completed, l:entry.id) < 0
      let l:next_id = l:entry.id
      break
    endif
  endfor

  if l:next_id > 0
    call Game_LoadLevelMeta(l:next_id)
  endif
  " If all levels complete, stay on last level's lore

  call GameTransition('LORE')
endfunction

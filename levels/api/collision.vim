" Collision API for Escape Vim
" Wall detection and collision response

" State
let s:wall_char = '█'
let s:last_valid_pos = [0, 0]  " character coordinates
let s:in_error_state = 0
let s:error_duration_ms = 300
let s:wall_callback = v:null
let s:spy_callback = v:null    " Called on spy collision (defeat)

" Check if a position is a wall
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @return: 1 if wall, 0 if passable
function! Collision_IsWall(line_num, char_col)
  let l:char = Pos_GetChar(a:line_num, a:char_col)
  return l:char == s:wall_char
endfunction

" Set the wall character to detect
" @param char: single character string
function! Collision_SetWallChar(char)
  let s:wall_char = a:char
endfunction

" Set error feedback duration
" @param ms: milliseconds
function! Collision_SetErrorDuration(ms)
  let s:error_duration_ms = a:ms
endfunction

" Register callback for wall collision
" @param Callback: funcref receiving (wall_line, wall_col)
function! Collision_SetWallCallback(Callback)
  let s:wall_callback = a:Callback
endfunction

" Set the last valid position (used during initialization)
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
function! Collision_SetLastValidPos(line_num, char_col)
  let s:last_valid_pos = [a:line_num, a:char_col]
endfunction

" Internal: Enter error state with visual feedback
function! s:EnterErrorState(line, col)
  let s:in_error_state = 1

  " Visual feedback
  call Highlight_AddTimed('ErrorCell', a:line, a:col, s:error_duration_ms)

  " Callback
  if s:wall_callback != v:null
    call s:wall_callback(a:line, a:col)
  endif

  " Clear error state after delay - use tick system if available
  if exists('*Tick_After') && Tick_IsRunning()
    let l:ticks = Tick_MsToTicks(s:error_duration_ms)
    call Tick_After('collision_error', l:ticks, {tick -> execute('let s:in_error_state = 0')})
  else
    call timer_start(s:error_duration_ms, {-> execute('let s:in_error_state = 0')})
  endif
endfunction

" Handle tick-based movement collision (called before move attempt)
" Provides visual feedback when player tries to move into a wall
" @param line: attempted line position
" @param col: attempted column position
function! Collision_OnTickedMove(line, col)
  if !s:in_error_state
    call s:EnterErrorState(a:line, a:col)
  endif
endfunction

" Handle cursor movement - call from CursorMoved autocommand
" Returns dict with 'blocked' (0/1) and 'pos' [line, char_col]
" @return: {'blocked': 0/1, 'pos': [line, char_col]}
function! Collision_OnMove()
  let l:cur_pos = Pos_GetCursor()
  let l:line = l:cur_pos[0]
  let l:col = l:cur_pos[1]

  if Collision_IsWall(l:line, l:col)
    " Bounce back to last valid position
    if s:last_valid_pos[0] > 0
      call Pos_SetCursor(s:last_valid_pos[0], s:last_valid_pos[1])
    endif

    " Visual feedback (only if not already in error state)
    if !s:in_error_state
      call s:EnterErrorState(l:line, l:col)
    endif

    return {'blocked': 1, 'pos': s:last_valid_pos}
  endif

  " Valid move
  let s:last_valid_pos = [l:line, l:col]
  return {'blocked': 0, 'pos': [l:line, l:col]}
endfunction

" Reset collision state (call when leaving level)
function! Collision_Cleanup()
  let s:last_valid_pos = [0, 0]
  let s:in_error_state = 0
  let s:wall_callback = v:null
  let s:spy_callback = v:null
endfunction

" ============================================================================
" Spy Collision Detection
" ============================================================================

" Register callback for spy collision (defeat)
" @param Callback: funcref called when player touches spy
function! Collision_SetSpyCallback(Callback)
  let s:spy_callback = a:Callback
endfunction

" Check if player is colliding with any spy
" Called from player movement and spy movement
" @param player_pos: [line, col]
function! Collision_CheckSpies(player_pos)
  if !exists('*Enemy_CheckCollision')
    return
  endif

  if Enemy_CheckCollision(a:player_pos)
    call Collision_OnSpyCollision()
  endif
endfunction

" Called when spy collision is detected
" Triggers the defeat callback
function! Collision_OnSpyCollision()
  if s:spy_callback != v:null
    call s:spy_callback()
  endif
endfunction

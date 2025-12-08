" Player API for Escape Vim
" Player rendering and position tracking

" State
let s:player_char = '@'
let s:floor_char = ' '
let s:player_pos = [0, 0]      " [line, char_col] in character coordinates
let s:player_highlight_id = 0
let s:editing_mode = 0         " If 1, use color-only rendering (don't change char)

" Tick-governed movement state
let s:movement_queue = ''       " Most recent queued direction: 'h', 'j', 'k', 'l', or ''
let s:move_interval = 2         " Ticks between moves (2 = 10 moves/sec at 50ms tick)
let s:last_move_tick = 0
let s:tick_movement_enabled = 0 " Whether to use tick-based movement

" Internal: draw player at current position
function! s:DrawPlayer()
  " In editing mode, only apply highlight (don't change the character)
  " This lets the player "become" the letter they're standing on visually
  if !s:editing_mode
    call Buffer_SetChar(s:player_pos[0], s:player_pos[1], s:player_char)
  endif

  " Update highlight
  if s:player_highlight_id
    call Highlight_Remove(s:player_highlight_id)
  endif
  " Use different highlight for editing mode (more visible yellow) vs maze mode (white on black)
  let l:highlight_group = s:editing_mode ? 'EditingCursor' : 'PlayerChar'
  let s:player_highlight_id = Highlight_Add(l:highlight_group, s:player_pos[0], s:player_pos[1])
endfunction

" Initialize player at a character position
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
function! Player_Init(line_num, char_col)
  let s:player_pos = [a:line_num, a:char_col]
  call Pos_SetCursor(a:line_num, a:char_col)
  call s:DrawPlayer()
endfunction

" Get current player position in character coordinates
" @return: [line_num, char_col]
function! Player_GetPos()
  return copy(s:player_pos)
endfunction

" Update player position (call from CursorMoved handler)
" Handles drawing/clearing automatically
" @param line_num: new line
" @param char_col: new character column
function! Player_MoveTo(line_num, char_col)
  " Clear old position (only in non-editing mode where we draw @)
  if s:player_pos[0] > 0 && !s:editing_mode
    call Buffer_SetChar(s:player_pos[0], s:player_pos[1], s:floor_char)
  endif

  " Update position
  let s:player_pos = [a:line_num, a:char_col]

  " Draw at new position
  call s:DrawPlayer()
endfunction

" Redraw player at current position (useful after buffer changes)
function! Player_Redraw()
  call s:DrawPlayer()
endfunction

" Set the player character
" @param char: single character string
function! Player_SetChar(char)
  let s:player_char = a:char
endfunction

" Set the floor character (what's left behind when player moves)
" @param char: single character string
function! Player_SetFloorChar(char)
  let s:floor_char = a:char
endfunction

" Enable editing mode (color-only rendering, don't change characters)
" Used for editing levels where player moves over text
function! Player_EnableEditingMode()
  let s:editing_mode = 1
endfunction

" Disable editing mode (back to @ rendering)
function! Player_DisableEditingMode()
  let s:editing_mode = 0
endfunction

" Check if editing mode is enabled
function! Player_IsEditingMode()
  return s:editing_mode
endfunction

" Reset player state (call when leaving level)
function! Player_Cleanup()
  if s:player_highlight_id
    call Highlight_Remove(s:player_highlight_id)
    let s:player_highlight_id = 0
  endif
  let s:player_pos = [0, 0]

  " Reset tick movement state (cleanup handled by prefix unsubscribe)
  let s:tick_movement_enabled = 0
  let s:movement_queue = ''
  let s:last_move_tick = 0

  " Reset editing mode
  let s:editing_mode = 0
endfunction

" ============================================================================
" Tick-Governed Movement System
" ============================================================================

" Enable tick-based movement (call during level setup for levels that need it)
function! Player_EnableTickMovement()
  let s:tick_movement_enabled = 1
  let s:movement_queue = ''
  let s:last_move_tick = Tick_GetCurrent()

  " Subscribe to tick system
  call Tick_Subscribe('gameplay:player', function('s:OnMovementTick'), 1)
endfunction

" Disable tick-based movement (for levels using native Vim motions)
" Note: cleanup is handled by prefix unsubscribe on state change
function! Player_DisableTickMovement()
  let s:tick_movement_enabled = 0
  let s:movement_queue = ''
endfunction

" Check if tick movement is enabled
function! Player_IsTickMovementEnabled()
  return s:tick_movement_enabled
endfunction

" Queue a movement direction (called by key mappings)
" Only keeps the most recent direction - no queue buildup
" @param direction: 'h', 'j', 'k', or 'l'
function! Player_QueueMove(direction)
  if !s:tick_movement_enabled
    return
  endif
  let s:movement_queue = a:direction
endfunction

" Set movement interval (for speed powerups/debuffs)
" @param n: ticks between moves (1 = fastest, higher = slower)
function! Player_SetMoveInterval(n)
  let s:move_interval = a:n
endfunction

" Get current movement interval
function! Player_GetMoveInterval()
  return s:move_interval
endfunction

" Internal: Process movement on tick
" @param tick: current tick number
" @return: 1 to stay subscribed
function! s:OnMovementTick(tick)
  " Check if movement interval has elapsed
  if a:tick - s:last_move_tick < s:move_interval
    return 1
  endif

  " Check if there's a queued movement
  if s:movement_queue == ''
    return 1
  endif

  " Calculate new position based on direction
  let l:cur_pos = s:player_pos
  let l:new_line = l:cur_pos[0]
  let l:new_col = l:cur_pos[1]

  if s:movement_queue == 'h'
    let l:new_col -= 1
  elseif s:movement_queue == 'l'
    let l:new_col += 1
  elseif s:movement_queue == 'k'
    let l:new_line -= 1
  elseif s:movement_queue == 'j'
    let l:new_line += 1
  endif

  " Clear the queue
  let s:movement_queue = ''
  let s:last_move_tick = a:tick

  " Check for wall collision before moving
  if Collision_IsWall(l:new_line, l:new_col)
    " Trigger wall collision feedback
    call Collision_OnTickedMove(l:new_line, l:new_col)
    return 1
  endif

  " Move the player
  call Player_MoveTo(l:new_line, l:new_col)

  " Update cursor position to match player
  call Pos_SetCursor(l:new_line, l:new_col)

  " Update collision tracking
  call Collision_SetLastValidPos(l:new_line, l:new_col)

  " Check for spy collision (if enemy system is loaded)
  if exists('*Collision_CheckSpies')
    call Collision_CheckSpies([l:new_line, l:new_col])
  endif

  return 1
endfunction

" Setup tick movement key mappings for the current buffer
function! Player_SetupTickMappings()
  nnoremap <buffer> <silent> h :call Player_QueueMove('h')<CR>
  nnoremap <buffer> <silent> j :call Player_QueueMove('j')<CR>
  nnoremap <buffer> <silent> k :call Player_QueueMove('k')<CR>
  nnoremap <buffer> <silent> l :call Player_QueueMove('l')<CR>
endfunction

" Remove tick movement key mappings
function! Player_ClearTickMappings()
  silent! nunmap <buffer> h
  silent! nunmap <buffer> j
  silent! nunmap <buffer> k
  silent! nunmap <buffer> l
endfunction

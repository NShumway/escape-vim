" Enemy (Spy) System for Escape Vim
" Manages spy entities: spawning, rendering, movement, cleanup

" ============================================================================
" Configuration
" ============================================================================

let s:spy_char = '☠'
let s:spy_highlight = 'SpyChar'

" ============================================================================
" State
" ============================================================================

" Dictionary of active spies: id -> spy state
let s:spies = {}

" ============================================================================
" Highlight Definition
" ============================================================================

" Define spy highlight (red on black for danger)
highlight SpyChar cterm=bold ctermfg=Red ctermbg=Black guifg=Red guibg=Black gui=bold

" ============================================================================
" Spy State Structure
" ============================================================================
"
" Each spy has:
" {
"   'id': 'spy1',
"   'pos': [5, 10],              " current [line, char_col]
"   'route': [...],              " list of vectors
"   'vector_idx': 0,             " current vector index
"   'move_interval': 2,          " ticks between moves
"   'last_move_tick': 0,
"   'highlight_id': -1,          " for cleanup
"   'original_char': ' ',        " character at spy's position (to restore)
" }

" ============================================================================
" Public API
" ============================================================================

" Spawn a spy at a position with a patrol route
" @param id: unique string identifier
" @param pos: [line, col] spawn position
" @param route: list of vectors defining patrol path
" @param speed: speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double)
function! Enemy_Spawn(id, pos, route, speed)
  " Calculate move interval from speed
  " Base interval is 2 ticks (10 moves/sec)
  " speed 1.0 -> interval 2
  " speed 0.5 -> interval 4
  " speed 2.0 -> interval 1
  let l:interval = float2nr(round(2.0 / a:speed))
  if l:interval < 1
    let l:interval = 1
  endif

  " Save the character at the spy's position
  let l:original = Pos_GetChar(a:pos[0], a:pos[1])

  let s:spies[a:id] = {
        \ 'id': a:id,
        \ 'pos': copy(a:pos),
        \ 'route': a:route,
        \ 'vector_idx': 0,
        \ 'move_interval': l:interval,
        \ 'last_move_tick': Tick_GetCurrent(),
        \ 'highlight_id': -1,
        \ 'original_char': l:original,
        \ }

  " Draw spy at initial position
  call s:DrawSpy(a:id)
endfunction

" Remove a specific spy
" @param id: spy identifier
function! Enemy_Remove(id)
  if !has_key(s:spies, a:id)
    return
  endif

  let l:spy = s:spies[a:id]

  " Restore original character
  call Buffer_SetChar(l:spy.pos[0], l:spy.pos[1], l:spy.original_char)

  " Remove highlight
  if l:spy.highlight_id >= 0
    call Highlight_Remove(l:spy.highlight_id)
  endif

  unlet s:spies[a:id]
endfunction

" Remove all spies (level cleanup)
function! Enemy_RemoveAll()
  for l:id in keys(s:spies)
    call Enemy_Remove(l:id)
  endfor
endfunction

" Get list of all spy positions
" @return: list of [line, col] positions
function! Enemy_GetPositions()
  let l:positions = []
  for l:spy in values(s:spies)
    call add(l:positions, copy(l:spy.pos))
  endfor
  return l:positions
endfunction

" Get a specific spy's position
" @param id: spy identifier
" @return: [line, col] or empty list if not found
function! Enemy_GetPos(id)
  if has_key(s:spies, a:id)
    return copy(s:spies[a:id].pos)
  endif
  return []
endfunction

" Check if player position collides with any spy
" Collision occurs if player is ON or ADJACENT to a spy (caught if too close)
" @param player_pos: [line, col]
" @return: 1 if collision, 0 otherwise
function! Enemy_CheckCollision(player_pos)
  let l:pline = a:player_pos[0]
  let l:pcol = a:player_pos[1]

  for l:spy in values(s:spies)
    let l:sline = l:spy.pos[0]
    let l:scol = l:spy.pos[1]

    " Check if player is on spy or adjacent (Manhattan distance <= 1)
    let l:dist_line = abs(l:pline - l:sline)
    let l:dist_col = abs(l:pcol - l:scol)

    if l:dist_line <= 1 && l:dist_col <= 1
      " Adjacent or same position = caught
      return 1
    endif
  endfor
  return 0
endfunction

" Tick subscriber - moves all spies
" @param tick: current tick number
" @return: 1 to stay subscribed
function! Enemy_OnTick(tick)
  for l:id in keys(s:spies)
    call s:UpdateSpy(l:id, a:tick)
  endfor
  return 1
endfunction

" Start enemy tick subscription
function! Enemy_Start()
  call Tick_Subscribe('gameplay:enemy', function('Enemy_OnTick'), 1)
endfunction

" ============================================================================
" Internal Functions
" ============================================================================

" Draw spy at its current position
function! s:DrawSpy(id)
  let l:spy = s:spies[a:id]

  " Draw character
  call Buffer_SetChar(l:spy.pos[0], l:spy.pos[1], s:spy_char)

  " Add highlight
  if l:spy.highlight_id >= 0
    call Highlight_Remove(l:spy.highlight_id)
  endif
  let s:spies[a:id].highlight_id = Highlight_Add(s:spy_highlight, l:spy.pos[0], l:spy.pos[1])
endfunction

" Erase spy from its current position (restore original char)
function! s:EraseSpy(id)
  let l:spy = s:spies[a:id]

  " Restore original character
  call Buffer_SetChar(l:spy.pos[0], l:spy.pos[1], l:spy.original_char)

  " Remove highlight
  if l:spy.highlight_id >= 0
    call Highlight_Remove(l:spy.highlight_id)
    let s:spies[a:id].highlight_id = -1
  endif
endfunction

" Update a single spy's position
function! s:UpdateSpy(id, tick)
  " Guard: spy may have been removed during collision cleanup
  if !has_key(s:spies, a:id)
    return
  endif

  let l:spy = s:spies[a:id]

  " Check if move interval has elapsed
  if a:tick - l:spy.last_move_tick < l:spy.move_interval
    return
  endif

  " Get current vector
  let l:route = l:spy.route
  if empty(l:route)
    return
  endif

  let l:vector = l:route[l:spy.vector_idx]

  " Calculate next position
  let l:new_pos = Patrol_NextPos(l:spy.pos, l:vector)

  " Erase from old position
  call s:EraseSpy(a:id)

  " Save character at new position before overwriting
  let l:new_original = Pos_GetChar(l:new_pos[0], l:new_pos[1])

  " Update spy state
  let s:spies[a:id].pos = l:new_pos
  let s:spies[a:id].original_char = l:new_original
  let s:spies[a:id].last_move_tick = a:tick

  " Check if we've reached the end of current vector
  if Patrol_IsVectorComplete(l:new_pos, l:vector)
    " Move to next vector
    let s:spies[a:id].vector_idx = Patrol_NextVector(l:route, l:spy.vector_idx)
  endif

  " Draw at new position
  call s:DrawSpy(a:id)

  " Check for collision with player (spy walked into player)
  if exists('*Player_GetPos') && exists('*Collision_OnSpyCollision')
    let l:player_pos = Player_GetPos()
    if Enemy_CheckCollision(l:player_pos)
      call Collision_OnSpyCollision()
    endif
  endif
endfunction

" Get spy character
function! Enemy_GetChar()
  return s:spy_char
endfunction

" Set spy character
function! Enemy_SetChar(char)
  let s:spy_char = a:char
endfunction

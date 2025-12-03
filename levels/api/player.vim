" Player API for Escape Vim
" Player rendering and position tracking

" State
let s:player_char = '@'
let s:floor_char = ' '
let s:player_pos = [0, 0]      " [line, char_col] in character coordinates
let s:player_highlight_id = 0

" Internal: draw player at current position
function! s:DrawPlayer()
  call Buffer_SetChar(s:player_pos[0], s:player_pos[1], s:player_char)

  " Update highlight
  if s:player_highlight_id
    call Highlight_Remove(s:player_highlight_id)
  endif
  let s:player_highlight_id = Highlight_Add('PlayerChar', s:player_pos[0], s:player_pos[1])
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
  " Clear old position
  if s:player_pos[0] > 0
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

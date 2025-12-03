" Position API for Escape Vim
" Handles all byte ↔ character position conversions
"
" All game logic works in CHARACTER positions (1-indexed).
" This module handles conversions to/from Vim's byte positions.

" Convert character column to byte column
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @return: 1-indexed byte column for use with cursor(), matchaddpos(), etc.
function! Pos_CharToBytes(line_num, char_col)
  let l:content = getline(a:line_num)
  if a:char_col <= 1
    return 1
  endif
  let l:byte_idx = byteidx(l:content, a:char_col - 1)
  return l:byte_idx < 0 ? 1 : l:byte_idx + 1
endfunction

" Convert byte column to character column
" @param line_num: 1-indexed line number
" @param byte_col: 1-indexed byte column (from col())
" @return: 1-indexed character column
function! Pos_BytesToChar(line_num, byte_col)
  let l:content = getline(a:line_num)
  if a:byte_col <= 1
    return 1
  endif
  return charidx(l:content, a:byte_col - 1) + 1
endfunction

" Get character at position using character coordinates
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @return: single character string
function! Pos_GetChar(line_num, char_col)
  let l:content = getline(a:line_num)
  return strcharpart(l:content, a:char_col - 1, 1)
endfunction

" Move cursor to character position
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
function! Pos_SetCursor(line_num, char_col)
  let l:byte_col = Pos_CharToBytes(a:line_num, a:char_col)
  call cursor(a:line_num, l:byte_col)
endfunction

" Get cursor position in character coordinates
" @return: [line_num, char_col] both 1-indexed
function! Pos_GetCursor()
  let l:line = line('.')
  let l:byte_col = col('.')
  return [l:line, Pos_BytesToChar(l:line, l:byte_col)]
endfunction

" Get cursor position in byte coordinates (raw Vim values)
" @return: [line_num, byte_col] both 1-indexed
function! Pos_GetCursorBytes()
  return [line('.'), col('.')]
endfunction

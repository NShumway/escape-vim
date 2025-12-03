" Buffer API for Escape Vim
" Safe buffer manipulation with automatic modifiable toggling
" and character-based access.

" Set a character at a position (character coordinates)
" Handles modifiable toggle automatically
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @param char: single character to place
function! Buffer_SetChar(line_num, char_col, char)
  let l:content = getline(a:line_num)
  let l:before = strcharpart(l:content, 0, a:char_col - 1)
  let l:after = strcharpart(l:content, a:char_col)

  setlocal modifiable
  call setline(a:line_num, l:before . a:char . l:after)
  setlocal nomodifiable
endfunction

" Get a character at a position (character coordinates)
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @return: single character string
function! Buffer_GetChar(line_num, char_col)
  return Pos_GetChar(a:line_num, a:char_col)
endfunction

" Execute a function with buffer temporarily modifiable
" @param Callback: funcref to execute
function! Buffer_WithModifiable(Callback)
  setlocal modifiable
  try
    call a:Callback()
  finally
    setlocal nomodifiable
  endtry
endfunction

" Replace a range of characters on a line
" @param line_num: 1-indexed line number
" @param start_char: 1-indexed start character column
" @param end_char: 1-indexed end character column (inclusive)
" @param replacement: string to insert
function! Buffer_ReplaceRange(line_num, start_char, end_char, replacement)
  let l:content = getline(a:line_num)
  let l:before = strcharpart(l:content, 0, a:start_char - 1)
  let l:after = strcharpart(l:content, a:end_char)

  setlocal modifiable
  call setline(a:line_num, l:before . a:replacement . l:after)
  setlocal nomodifiable
endfunction

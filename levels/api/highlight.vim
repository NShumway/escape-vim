" Highlight API for Escape Vim
" Centralized highlight/match management with automatic position conversion

" Track all active highlights for cleanup
let s:active_highlights = {}  " id -> {group, line, col}

" Define standard highlight groups
highlight ErrorCell cterm=reverse gui=reverse
highlight PlayerChar cterm=bold ctermfg=White ctermbg=Black guifg=White guibg=Black

" Override cursor highlighting to match PlayerChar (white on black)
highlight Cursor ctermfg=White ctermbg=Black guifg=White guibg=Black
highlight CursorLine NONE
highlight CursorColumn NONE

" Add highlight at character position
" @param group: highlight group name (e.g., 'ErrorCell', 'PlayerChar')
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @return: match ID for later removal
function! Highlight_Add(group, line_num, char_col)
  let l:byte_col = Pos_CharToBytes(a:line_num, a:char_col)
  let l:id = matchaddpos(a:group, [[a:line_num, l:byte_col]])
  let s:active_highlights[l:id] = {'group': a:group, 'line': a:line_num, 'col': a:char_col}
  return l:id
endfunction

" Remove a highlight by ID
" @param match_id: ID returned from Highlight_Add
function! Highlight_Remove(match_id)
  silent! call matchdelete(a:match_id)
  if has_key(s:active_highlights, a:match_id)
    unlet s:active_highlights[a:match_id]
  endif
endfunction

" Remove all highlights managed by this module
function! Highlight_ClearAll()
  for l:id in keys(s:active_highlights)
    silent! call matchdelete(l:id)
  endfor
  let s:active_highlights = {}
endfunction

" Add a temporary highlight that auto-removes after delay
" @param group: highlight group name
" @param line_num: 1-indexed line number
" @param char_col: 1-indexed character column
" @param duration_ms: milliseconds before auto-removal
" @return: match ID
function! Highlight_AddTimed(group, line_num, char_col, duration_ms)
  let l:id = Highlight_Add(a:group, a:line_num, a:char_col)
  call timer_start(a:duration_ms, {-> Highlight_Remove(l:id)})
  return l:id
endfunction

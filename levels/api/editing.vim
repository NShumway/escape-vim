" Editing API for Escape Vim
" Handles text editing levels (4-8) with target matching
"
" DESIGN: Use native Vim editing. No custom insert/delete handlers.
" The only special logic is:
" 1. Check if editable text matches target text
" 2. Update exit tile color (green=match, red=mismatch)
" 3. Handle :wq to check win condition

" State
let s:target_text = ''
let s:editable_region = {}  " {start_line, end_line, start_col, end_col}
let s:exit_pos = [0, 0]
let s:exit_highlight_id = 0
let s:is_editing_level = 0

" Highlight groups for exit tile status
highlight ExitWin ctermfg=Black ctermbg=Green guifg=Black guibg=Green
highlight ExitLose ctermfg=Black ctermbg=Red guifg=Black guibg=Red

" Initialize editing level
" @param meta: level metadata dictionary
function! Editing_Init(meta)
  let s:is_editing_level = 1
  let s:target_text = get(a:meta, 'target_text', '')
  let s:editable_region = get(a:meta, 'editable_region', {})
  let s:exit_pos = get(a:meta, 'exit_cursor', [0, 0])

  " Set up autocommand to update exit status after any text change
  augroup EditingLevel
    autocmd!
    autocmd TextChanged,TextChangedI <buffer> call s:UpdateExitStatus()
  augroup END

  " Initial status update
  call s:UpdateExitStatus()
endfunction

" Check if this is an editing level
function! Editing_IsActive()
  return s:is_editing_level
endfunction

" Check if current editable text matches target
" @return: 1 if match, 0 if not
function! Editing_CheckMatch()
  let l:current = s:GetEditableText()
  return l:current ==# s:target_text
endfunction

" Get the current text from the editable region
" @return: string with newlines for multi-line
function! s:GetEditableText()
  if empty(s:editable_region)
    return ''
  endif

  let l:lines = []
  let l:start_line = s:editable_region.start_line
  let l:end_line = s:editable_region.end_line
  let l:start_col = s:editable_region.start_col
  let l:end_col = s:editable_region.end_col

  for l:lnum in range(l:start_line, l:end_line)
    let l:line_content = getline(l:lnum)
    " Extract the editable portion of the line
    let l:text = strcharpart(l:line_content, l:start_col - 1, l:end_col - l:start_col + 1)
    " Trim trailing spaces to match target
    let l:text = substitute(l:text, '\s*$', '', '')
    call add(l:lines, l:text)
  endfor

  return join(l:lines, "\n")
endfunction

" Update exit tile highlight based on match status
function! s:UpdateExitStatus()
  " Remove old highlight
  if s:exit_highlight_id
    silent! call matchdelete(s:exit_highlight_id)
    let s:exit_highlight_id = 0
  endif

  " Add new highlight based on match
  if s:exit_pos[0] > 0 && s:exit_pos[1] > 0
    let l:group = Editing_CheckMatch() ? 'ExitWin' : 'ExitLose'
    " Convert char col to byte col for matchaddpos
    let l:byte_col = Pos_CharToBytes(s:exit_pos[0], s:exit_pos[1])
    let s:exit_highlight_id = matchaddpos(l:group, [[s:exit_pos[0], l:byte_col]])
  endif
endfunction

" Get exit position
function! Editing_GetExitPos()
  return copy(s:exit_pos)
endfunction

" Clean up editing state
function! Editing_Cleanup()
  if s:exit_highlight_id
    silent! call matchdelete(s:exit_highlight_id)
    let s:exit_highlight_id = 0
  endif

  augroup EditingLevel
    autocmd!
  augroup END

  let s:target_text = ''
  let s:editable_region = {}
  let s:exit_pos = [0, 0]
  let s:is_editing_level = 0
endfunction
